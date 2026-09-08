import BikeDomain
import Foundation
import RideSession
import RideSessionDomain
import SettingsDomain
import VehicleSession

func makeLiveRideSessionServiceFixture(
    speedSource: SpeedSource = .motorcycle,
    initialVehicleIdentity: RideVehicleIdentity = .temporary(UUID()),
    rideVehicleSession: (any VehicleSessionService)? = nil,
    tripRepository: SessionTripRepository = .init(),
    sleepController: SessionSleepController = .init(),
    identityResolver: any RideVehicleIdentityResolving = SessionIdentityResolver()
) -> LiveRideSessionServiceFixture {
    let date = Date(timeIntervalSince1970: 1_000)
    let bikeRepository = SessionBikeRepository()
    let settingsRepository = SessionSettingsRepository(speedSource: speedSource)
    let deviceSpeedRepository = SessionDeviceSpeedRepository()
    let profileRepository = SessionProfileRepository()
    let batteryHealthRepository = SessionBatteryHealthRepository()
    let liveVehicleService = makeRideSessionVehicleService(
        date: date,
        repositories: RideSessionVehicleServiceRepositories(
            bike: bikeRepository,
            settings: settingsRepository,
            deviceSpeed: deviceSpeedRepository,
            profile: profileRepository,
            batteryHealth: batteryHealthRepository
        )
    )
    let vehicleService = rideVehicleSession ?? liveVehicleService
    let service = LiveRideSessionService(
        useCases: .init(prepare: .init(repository: tripRepository)),
        vehicleSession: vehicleService,
        persistence: .init(repository: tripRepository),
        identityResolver: identityResolver,
        initialContext: .init(
            applicationSessionID: UUID(),
            vehicleIdentity: initialVehicleIdentity
        ),
        now: { date },
        sleep: { duration in try await sleepController.sleep(for: duration) }
    )
    return LiveRideSessionServiceFixture(
        service: service,
        vehicleService: vehicleService,
        bikeRepository: bikeRepository,
        deviceSpeedRepository: deviceSpeedRepository,
        tripRepository: tripRepository,
        sleepController: sleepController,
        date: date
    )
}

private struct RideSessionVehicleServiceRepositories {
    let bike: SessionBikeRepository
    let settings: SessionSettingsRepository
    let deviceSpeed: SessionDeviceSpeedRepository
    let profile: SessionProfileRepository
    let batteryHealth: SessionBatteryHealthRepository
}

private func makeRideSessionVehicleService(
    date: Date,
    repositories: RideSessionVehicleServiceRepositories
) -> LiveVehicleSessionService {
    let observeBatteryHealth = ObserveBikeBatteryHealthUseCase(repository: repositories.batteryHealth)
    let startBatteryHealthMonitoring = StartBatteryHealthMonitoringUseCase(
        repository: repositories.batteryHealth
    )
    let stopBatteryHealthMonitoring = StopBatteryHealthMonitoringUseCase(
        repository: repositories.batteryHealth
    )
    return LiveVehicleSessionService(
        useCases: .init(
            observeTelemetry: .init(repository: repositories.bike),
            observeConnection: .init(repository: repositories.bike),
            observeSettings: .init(repository: repositories.settings),
            observeDeviceSpeed: .init(repository: repositories.deviceSpeed),
            observeIMU: .init(repository: SessionIMURepository()),
            startIMUMonitoring: .init(repository: SessionIMURepository()),
            stopIMUMonitoring: .init(repository: SessionIMURepository()),
            loadMotionCalibration: .init(repository: SessionMotionCalibrationRepository()),
            saveMotionCalibration: .init(repository: SessionMotionCalibrationRepository()),
            observeBikeProfile: .init(repository: repositories.profile),
            observeBatteryHealth: observeBatteryHealth,
            startBatteryHealthMonitoring: startBatteryHealthMonitoring,
            stopBatteryHealthMonitoring: stopBatteryHealthMonitoring,
            readBikeStatusSnapshot: .init(repository: repositories.bike)
        ),
        powerModeRefreshCoordinator: makeVehiclePowerModeRefreshCoordinator(),
        batteryHealthMonitoringCoordinator: .init(
            observeBatteryHealth: observeBatteryHealth,
            startBatteryHealthMonitoring: startBatteryHealthMonitoring,
            stopBatteryHealthMonitoring: stopBatteryHealthMonitoring
        ),
        speedResolver: .init(now: { date }, maximumAccuracyMetersPerSecond: 5, maximumSampleAge: 5),
        motionEstimator: .init(
            profile: nil,
            now: { date },
            maximumSampleAge: 5,
            attitudeFilter: .init(),
            calibrationTracker: .init(),
            locationResolver: .init(
                now: { date },
                maximumSampleAge: 5,
                minimumCourseSpeedKilometersPerHour: 5,
                maximumCourseAccuracyDegrees: 35
            )
        ),
        sleep: { duration in try await Task.sleep(for: duration) }
    )
}

private func makeVehiclePowerModeRefreshCoordinator() -> VehiclePowerModeRefreshCoordinator {
    .init(
        refreshPowerModeConfiguration: nil,
        refreshTractionControlConfiguration: nil
    )
}

struct LiveRideSessionServiceFixture {
    let service: LiveRideSessionService
    let vehicleService: any VehicleSessionService
    let bikeRepository: SessionBikeRepository
    let deviceSpeedRepository: SessionDeviceSpeedRepository
    let tripRepository: SessionTripRepository
    let sleepController: SessionSleepController
    let date: Date

    func start() async {
        await vehicleService.start()
        await service.start()
    }

    func stop() async {
        await service.stop()
        await vehicleService.stop()
    }

    func latestSnapshot() async -> RideSessionSnapshot {
        let stream = await service.observe()
        for await snapshot in stream { return snapshot }
        fatalError("Ride session stream finished unexpectedly")
    }
}
