import Foundation
import RideSession
import RideSessionDomain
import SettingsDomain
import VehicleSession

func makeLiveRideSessionServiceFixture(
    speedSource: SpeedSource = .motorcycle
) -> LiveRideSessionServiceFixture {
    let date = Date(timeIntervalSince1970: 1_000)
    let bikeRepository = SessionBikeRepository()
    let settingsRepository = SessionSettingsRepository(speedSource: speedSource)
    let deviceSpeedRepository = SessionDeviceSpeedRepository()
    let profileRepository = SessionProfileRepository()
    let batteryHealthRepository = SessionBatteryHealthRepository()
    let tripRepository = SessionTripRepository()
    let vehicleService = LiveVehicleSessionService(
        useCases: .init(
            observeTelemetry: .init(repository: bikeRepository),
            observeConnection: .init(repository: bikeRepository),
            observeSettings: .init(repository: settingsRepository),
            observeDeviceSpeed: .init(repository: deviceSpeedRepository),
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
        )
    )
    let service = LiveRideSessionService(
        useCases: .init(prepare: .init(repository: tripRepository)),
        vehicleSession: vehicleService,
        persistence: .init(repository: tripRepository),
        identityResolver: SessionIdentityResolver(),
        initialContext: .init(
            applicationSessionID: UUID(),
            vehicleIdentity: .temporary(UUID())
        ),
        now: { date }
    )
    return LiveRideSessionServiceFixture(
        service: service,
        vehicleService: vehicleService,
        bikeRepository: bikeRepository,
        deviceSpeedRepository: deviceSpeedRepository,
        tripRepository: tripRepository,
        date: date
    )
}

struct LiveRideSessionServiceFixture {
    let service: LiveRideSessionService
    let vehicleService: LiveVehicleSessionService
    let bikeRepository: SessionBikeRepository
    let deviceSpeedRepository: SessionDeviceSpeedRepository
    let tripRepository: SessionTripRepository
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
