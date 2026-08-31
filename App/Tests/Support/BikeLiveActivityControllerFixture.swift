import BikeDomain
import BLETraceDomain
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
            updateInterval: FENRRuntimeConstants.LiveActivity.chargingUpdateInterval,
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

@MainActor
final class AppLifecycleControllerFixture {
    let repository = SessionSpyRepository()
    let vehicleSession = LifecycleVehicleSessionSpy()
    let rideSession = LifecycleRideSessionSpy()
    let lifecycleController: AppLifecycleController

    init(
        bleTraceStoragePreparer: any BLETraceStoragePreparing = NoOpBLETraceRepository()
    ) {
        let profileRepository = SetupProfileRepository(
            profile: .init(vin: "FENRTEST000000001")
        )
        let setupFlow = BikeSetupFlowController(
            useCases: .init(
                load: .init(repository: profileRepository),
                clear: .init(repository: profileRepository)
            ),
            forceOnboarding: false
        )
        let sessionController = BikeSessionController(
            useCases: .init(
                startRepository: .init(repository: repository),
                stopRepository: .init(repository: repository),
                connectToBike: .init(repository: repository),
                disconnectFromBike: .init(repository: repository)
            )
        )
        let liveActivityController = BikeLiveActivityController(
            vehicleSession: vehicleSession,
            activityClient: FakeBikeLiveActivityClient(),
            clock: FakeBikeLiveActivityClock(),
            updateInterval: FENRRuntimeConstants.LiveActivity.chargingUpdateInterval,
            stateMapper: BikeLiveActivityStateMapper(
                makeDashboardMapper: { settings in
                    RideDashboardMapperFactory.makeChargingMapper(
                        settings: settings,
                        locale: .init(identifier: "en_US")
                    )
                },
                makeSpeedMapper: { measurementSystem in
                    RideDashboardMapperFactory.makeMeasurementMapper(
                        measurementSystem: measurementSystem,
                        locale: .init(identifier: "en_US")
                    )
                },
                telemetryFreshnessInterval: FENRRuntimeConstants.Telemetry.freshnessInterval,
                completeBatteryPercent: FENRRuntimeConstants.LiveActivity.completeBatteryPercent
            )
        )
        lifecycleController = AppLifecycleController(
            sessionController: sessionController,
            setupFlow: setupFlow,
            bikeLiveActivityController: liveActivityController,
            rideSession: rideSession,
            vehicleSession: vehicleSession,
            bleTraceStoragePreparer: bleTraceStoragePreparer
        )
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
