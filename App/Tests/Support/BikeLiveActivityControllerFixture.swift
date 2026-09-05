import BikeDomain
import Foundation
import RideDashboard
import RuntimeConfiguration
import SettingsDomain
import VehicleSession

@MainActor
final class BikeLiveActivityControllerFixture {
    let repository = BikeLiveActivityRepository()
    let settingsRepository = BikeLiveActivitySettingsRepository()
    let activityClient = FakeBikeLiveActivityClient()
    let clock = FakeBikeLiveActivityClock()
    let timing = ControllableBikeLiveActivityTiming()
    let vehicleSession: LiveVehicleSessionService
    let controller: BikeLiveActivityController

    init() {
        let locale = Locale(identifier: "en_US")
        let vehicleSession = makeBikeLiveActivityVehicleSession(
            repository: repository,
            settingsRepository: settingsRepository
        )
        self.vehicleSession = vehicleSession
        controller = BikeLiveActivityController(
            vehicleSession: vehicleSession,
            activityClient: activityClient,
            clock: clock,
            timing: timing.makeTiming(),
            continuityPolicy: RideDashboardContinuityPolicy(),
            updatePolicy: BikeLiveActivityUpdatePolicy(
                updateInterval: FENRRuntimeConstants.LiveActivity.chargingUpdateInterval
            ),
            reconnectionNoticeDelay: FENRRuntimeConstants.RideDashboard.reconnectionNoticeDelay,
            stateMapper: BikeLiveActivityStateMapper(
                makeDashboardMapper: { settings in
                    RideDashboardMapperFactory.makeChargingMapper(
                        settings: settings,
                        locale: locale
                    )
                },
                makeSpeedMapper: { measurementSystem in
                    RideDashboardMapperFactory.makeMeasurementMapper(
                        measurementSystem: measurementSystem,
                        locale: locale
                    )
                },
                telemetryFreshnessInterval: FENRRuntimeConstants.Telemetry.freshnessInterval,
                completeBatteryPercent: FENRRuntimeConstants.LiveActivity.completeBatteryPercent
            )
        )
    }

    func currentSnapshot() async -> VehicleSessionSnapshot {
        var iterator = await vehicleSession.observe().makeAsyncIterator()
        return await iterator.next() ?? .init()
    }

    func start() async {
        await vehicleSession.start()
        controller.start()
        await Task.yield()
    }
}

private func makeBikeLiveActivityVehicleSession(
    repository: BikeLiveActivityRepository,
    settingsRepository: BikeLiveActivitySettingsRepository
) -> LiveVehicleSessionService {
    let observeBatteryHealth = ObserveBikeBatteryHealthUseCase(repository: repository)
    let startBatteryHealthMonitoring = StartBatteryHealthMonitoringUseCase(repository: repository)
    let stopBatteryHealthMonitoring = StopBatteryHealthMonitoringUseCase(repository: repository)
    return LiveVehicleSessionService(
        useCases: .init(
            observeTelemetry: .init(repository: repository),
            observeConnection: .init(repository: repository),
            observeSettings: .init(repository: settingsRepository),
            observeDeviceSpeed: .init(repository: BikeLiveActivityDeviceSpeedRepository()),
            observeIMU: .init(repository: BikeLiveActivityIMURepository()),
            startIMUMonitoring: .init(repository: BikeLiveActivityIMURepository()),
            stopIMUMonitoring: .init(repository: BikeLiveActivityIMURepository()),
            loadMotionCalibration: .init(repository: BikeLiveActivityMotionCalibrationRepository()),
            saveMotionCalibration: .init(repository: BikeLiveActivityMotionCalibrationRepository()),
            observeBikeProfile: .init(repository: BikeLiveActivityProfileRepository()),
            observeBatteryHealth: observeBatteryHealth,
            startBatteryHealthMonitoring: startBatteryHealthMonitoring,
            stopBatteryHealthMonitoring: stopBatteryHealthMonitoring,
            readBikeStatusSnapshot: .init(repository: repository)
        ),
        powerModeRefreshCoordinator: .init(
            refreshPowerModeConfiguration: nil,
            refreshTractionControlConfiguration: nil
        ),
        batteryHealthMonitoringCoordinator: .init(
            observeBatteryHealth: observeBatteryHealth,
            startBatteryHealthMonitoring: startBatteryHealthMonitoring,
            stopBatteryHealthMonitoring: stopBatteryHealthMonitoring
        ),
        speedResolver: .init(now: Date.init, maximumAccuracyMetersPerSecond: 5, maximumSampleAge: 5),
        motionEstimator: .init(
            profile: nil,
            now: Date.init,
            maximumSampleAge: 5,
            attitudeFilter: .init(),
            calibrationTracker: .init(),
            locationResolver: .init(
                now: Date.init,
                maximumSampleAge: 5,
                minimumCourseSpeedKilometersPerHour: 5,
                maximumCourseAccuracyDegrees: 35
            )
        ),
        sleep: { duration in try await Task.sleep(for: duration) }
    )
}
