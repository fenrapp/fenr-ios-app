import BikeDomain
import ChargeControl
import EnvironmentDomain
import Foundation
import RideSessionDomain
import RuntimeConfiguration
import SettingsDomain

#if DEBUG
@MainActor
enum RideDashboardPreviewFactory {
    static func makeViewModel(state: RideDashboardViewState) -> RideDashboardViewModel {
        let repository = RideDashboardPreviewRepository()
        let viewModel = RideDashboardViewModel(
            useCases: .init(
                observeTelemetry: .init(repository: repository),
                observeConnection: .init(repository: repository),
                observeSettings: .init(repository: PreviewAppSettingsRepository()),
                observeDeviceSpeed: .init(repository: PreviewDeviceSpeedRepository()),
                readBikeStatusSnapshot: .init(repository: repository)
            ),
            mapper: RideDashboardMapperFactory.makeRideMapper(locale: .autoupdatingCurrent),
            deviceSpeedResolver: DeviceSpeedResolver(
                now: Date.init,
                maximumAccuracyMetersPerSecond: 5,
                maximumSampleAge: FENRRuntimeConstants.RideDashboard.deviceSpeedMaximumSampleAge
            ),
            reconnectionGracePeriod: FENRRuntimeConstants.RideDashboard.reconnectionGracePeriod
        )
        viewModel.setPreviewState(state)
        return viewModel
    }
}

@MainActor
enum ChargingDashboardPreviewFactory {
    static func makeViewModel(state: ChargingDashboardViewState) -> ChargingDashboardViewModel {
        let repository = RideDashboardPreviewRepository()
        let locale = Locale.autoupdatingCurrent
        let makeMapper: @Sendable (AppSettings) -> ChargingDashboardMapper = { settings in
            RideDashboardMapperFactory.makeChargingMapper(settings: settings, locale: locale)
        }
        let viewModel = ChargingDashboardViewModel(
            useCases: .init(
                observeTelemetry: .init(repository: repository),
                observeBatteryHealth: .init(repository: repository),
                startBatteryHealthMonitoring: .init(repository: repository),
                stopBatteryHealthMonitoring: .init(repository: repository),
                observeSettings: .init(repository: PreviewAppSettingsRepository())
            ),
            chargeControl: ChargeControlSession(
                useCases: .init(
                    prepare: .init(repository: repository),
                    setPowerLimit: .init(repository: repository),
                    setTarget: .init(repository: repository)
                ),
                logger: ChargeControlLogStore(),
                stateUpdater: ChargeControlStateUpdater(normalizer: ChargeControlNormalizer()),
                taskScheduler: ChargeControlTaskScheduler()
            ),
            mapper: makeMapper(AppSettings()),
            makeMapper: makeMapper
        )
        viewModel.setPreviewState(state)
        return viewModel
    }
}

@MainActor
enum CurrentTripCardPreviewFactory {
    static func makeViewModel(state: DashboardCurrentTripViewData) -> CurrentTripCardViewModel {
        let bikeRepository = RideDashboardPreviewRepository()
        let tripRepository = PreviewRideTripRepository()
        let viewModel = CurrentTripCardViewModel(
            useCases: .init(
                observeTelemetry: .init(repository: bikeRepository),
                observeConnection: .init(repository: bikeRepository),
                observeSettings: .init(repository: PreviewAppSettingsRepository()),
                observeDeviceSpeed: .init(repository: PreviewDeviceSpeedRepository()),
                prepareRideTripSession: .init(repository: tripRepository),
                saveActiveRideTrip: .init(repository: tripRepository),
                completeRideTrip: .init(repository: tripRepository)
            ),
            mapper: RideDashboardMapperFactory.makeCurrentTripMapper(locale: .autoupdatingCurrent),
            deviceSpeedResolver: DeviceSpeedResolver(
                now: Date.init,
                maximumAccuracyMetersPerSecond: 5,
                maximumSampleAge: FENRRuntimeConstants.RideDashboard.deviceSpeedMaximumSampleAge
            ),
            applicationSessionID: UUID(),
            now: Date.init,
            onHistoryChanged: {}
        )
        viewModel.setPreviewState(state)
        return viewModel
    }
}

@MainActor
enum TripStatisticsCardPreviewFactory {
    static func makeViewModel(
        state: DashboardTripStatisticsViewData
    ) -> TripStatisticsCardViewModel {
        let repository = PreviewRideTripRepository()
        let viewModel = TripStatisticsCardViewModel(
            useCases: .init(
                loadStatistics: .init(
                    repository: repository,
                    aggregator: RideTripStatisticsAggregator()
                ),
                observeSettings: .init(repository: PreviewAppSettingsRepository())
            ),
            mapper: RideDashboardMapperFactory.makeTripStatisticsMapper(
                locale: .autoupdatingCurrent
            )
        )
        viewModel.setPreviewState(state)
        return viewModel
    }
}

private actor PreviewAppSettingsRepository: AppSettingsRepository {
    func load() -> AppSettings { .init() }
    func save(_: AppSettings) {}
    func observe() -> AsyncStream<AppSettings> { .init { $0.finish() } }
}

private actor PreviewDeviceSpeedRepository: DeviceSpeedRepository {
    func observeDeviceSpeed() -> AsyncStream<DeviceSpeedSample> { .init { $0.finish() } }
    func locationAuthorizationStatus() -> LocationAuthorizationStatus { .authorized }
    func requestLocationAuthorization() {}
}

private actor PreviewRideTripRepository: RideTripRepository {
    func prepare(applicationSessionID _: UUID) -> RideTrip? { nil }
    func saveActiveTrip(_: RideTrip) {}
    func completeTrip(_: RideTrip, at _: Date) {}
    func loadCompletedTrips() -> [RideTrip] { [] }
}

private actor RideDashboardPreviewRepository: BikeRepository, BikeBatteryHealthRepository {
    func start() async {}
    func stop() async {}
    func connect(vin _: String) async throws {}
    func disconnect() async throws {}
    func retrySecurityHandshake() async throws {}
    func readTelemetrySnapshot() async throws {}
    func observeTelemetry() async -> AsyncStream<BikeTelemetry> { .init { $0.finish() } }
    func observeConnection() async -> AsyncStream<BikeConnection> { .init { $0.finish() } }
    func observeDebugEvents() async -> AsyncStream<BikeDebugEvent> { .init { $0.finish() } }
    func startBatteryHealthMonitoring() async throws {}
    func stopBatteryHealthMonitoring() async {}
    func observeBatteryHealth() async -> AsyncStream<BikeBatteryHealth> { .init { $0.finish() } }
    func observeBatteryDatasetCaptures() async -> AsyncStream<BatteryDatasetCapture> { .init { $0.finish() } }
}
#endif
