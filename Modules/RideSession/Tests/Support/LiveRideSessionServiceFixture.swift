import Foundation
import RideSession
import RideSessionDomain
import SettingsDomain
import VehicleSession

func makeLiveRideSessionServiceFixture(
    speedSource: SpeedSource = .motorcycle,
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
    let liveVehicleService = LiveVehicleSessionService(
        useCases: .init(
            observeTelemetry: .init(repository: bikeRepository),
            observeConnection: .init(repository: bikeRepository),
            observeSettings: .init(repository: settingsRepository),
            observeDeviceSpeed: .init(repository: deviceSpeedRepository),
            observeIMU: .init(repository: SessionIMURepository()),
            startIMUMonitoring: .init(repository: SessionIMURepository()),
            stopIMUMonitoring: .init(repository: SessionIMURepository()),
            loadMotionCalibration: .init(repository: SessionMotionCalibrationRepository()),
            saveMotionCalibration: .init(repository: SessionMotionCalibrationRepository()),
            observeBikeProfile: .init(repository: profileRepository),
            observeBatteryHealth: .init(repository: batteryHealthRepository),
            startBatteryHealthMonitoring: .init(repository: batteryHealthRepository),
            stopBatteryHealthMonitoring: .init(repository: batteryHealthRepository),
            readBikeStatusSnapshot: .init(repository: bikeRepository)
        ),
        speedResolver: .init(
            now: { date },
            maximumAccuracyMetersPerSecond: 5,
            maximumSampleAge: 5
        ),
        motionEstimator: .init(
            profile: nil,
            now: { date },
            maximumSampleAge: 5,
            minimumGPSCourseSpeedKilometersPerHour: 5,
            maximumGPSCourseAccuracyDegrees: 35
        ),
        sleep: { duration in try await Task.sleep(for: duration) }
    )
    let vehicleService = rideVehicleSession ?? liveVehicleService
    let service = LiveRideSessionService(
        useCases: .init(prepare: .init(repository: tripRepository)),
        vehicleSession: vehicleService,
        persistence: .init(repository: tripRepository),
        identityResolver: identityResolver,
        initialContext: .init(
            applicationSessionID: UUID(),
            vehicleIdentity: .temporary(UUID())
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
