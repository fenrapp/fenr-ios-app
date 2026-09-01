import BikeDomain
import EnvironmentDomain
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
        vehicleSession = LiveVehicleSessionService(
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
                observeBatteryHealth: .init(repository: repository),
                startBatteryHealthMonitoring: .init(repository: repository),
                stopBatteryHealthMonitoring: .init(repository: repository),
                readBikeStatusSnapshot: .init(repository: repository)
            ),
            powerModeRefreshCoordinator: .init(
                refreshPowerModeConfiguration: nil, refreshTractionControlConfiguration: nil
            ),
            speedResolver: .init(
                now: { Date() },
                maximumAccuracyMetersPerSecond: 5,
                maximumSampleAge: 5
            ),
            motionEstimator: .init(
                profile: nil,
                now: Date.init,
                maximumSampleAge: 5,
                minimumGPSCourseSpeedKilometersPerHour: 5,
                maximumGPSCourseAccuracyDegrees: 35
            ),
            sleep: { duration in try await Task.sleep(for: duration) }
        )
        controller = BikeLiveActivityController(
            vehicleSession: vehicleSession,
            activityClient: activityClient,
            clock: clock,
            timing: timing.makeTiming(),
            continuityPolicy: RideDashboardContinuityPolicy(),
            updateInterval: FENRRuntimeConstants.LiveActivity.chargingUpdateInterval,
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

    func start() async {
        await vehicleSession.start()
        controller.start()
        await Task.yield()
    }
}

private actor BikeLiveActivityDeviceSpeedRepository: DeviceSpeedRepository {
    func observeDeviceSpeed() -> AsyncStream<DeviceSpeedSample> { .init { _ in } }
    func locationAuthorizationStatus() -> LocationAuthorizationStatus { .denied }
    func requestLocationAuthorization() {}
}

private actor BikeLiveActivityProfileRepository: BikeProfileRepository {
    func loadProfile() -> BikeProfile? { nil }
    func saveProfile(_: BikeProfile) {}
    func clearProfile() {}
}

private actor BikeLiveActivityIMURepository: BikeIMURepository {
    func observeIMU() -> AsyncStream<BikeIMUSample> { .init { _ in } }
    func startIMUMonitoring() throws {}
    func stopIMUMonitoring() {}
}

private actor BikeLiveActivityMotionCalibrationRepository: VehicleMotionCalibrationRepository {
    func load(vin _: String) -> VehicleMotionCalibration? { nil }
    func save(_: VehicleMotionCalibration) {}
}
