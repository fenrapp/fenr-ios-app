import BikeDomain
import ChargeControl
import Foundation
import RideSession
import RideSessionDomain
import SettingsDomain
import VehicleSession

#if DEBUG
@MainActor
enum RideDashboardPreviewFactory {
    static func makeViewModel(state: RideDashboardViewState) -> RideDashboardViewModel {
        let viewModel = RideDashboardViewModel(
            mapper: RideDashboardMapperFactory.makeRideMapper(locale: .autoupdatingCurrent),
            cardLayoutMapper: DashboardCardLayoutMapper(),
            vehicleSession: PreviewVehicleSessionService(),
            initialConnectionStabilityPeriod: .zero,
            reconnectionGracePeriod: .seconds(30)
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
        let makeMapper: @Sendable (AppSettings, String?) -> ChargingDashboardMapper = { settings, vin in
            RideDashboardMapperFactory.makeChargingMapper(settings: settings, locale: locale, vin: vin)
        }
        let viewModel = ChargingDashboardViewModel(
            vehicleSession: PreviewVehicleSessionService(),
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
            mapper: makeMapper(AppSettings(), nil),
            makeMapper: makeMapper
        )
        viewModel.setPreviewState(state)
        return viewModel
    }
}

@MainActor
enum CurrentTripCardPreviewFactory {
    static func makeViewModel(state: DashboardCurrentTripViewData) -> CurrentTripCardViewModel {
        let dependencies = makePreviewTripDependencies()
        let viewModel = CurrentTripCardViewModel(
            session: dependencies.session,
            mapper: RideDashboardMapperFactory.makeCurrentTripMapper(locale: .autoupdatingCurrent)
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
        let dependencies = makePreviewTripDependencies()
        let viewModel = TripStatisticsCardViewModel(
            useCases: .init(
                loadStatistics: .init(
                    repository: dependencies.tripRepository,
                    aggregator: RideTripStatisticsAggregator()
                )
            ),
            mapper: RideDashboardMapperFactory.makeTripStatisticsMapper(
                locale: .autoupdatingCurrent
            ),
            session: dependencies.session
        )
        viewModel.setPreviewState(state)
        return viewModel
    }
}

@MainActor
enum EfficiencyCardPreviewFactory {
    static func makeViewModel(state: DashboardEfficiencyViewData) -> EfficiencyCardViewModel {
        let dependencies = makePreviewTripDependencies()
        let viewModel = EfficiencyCardViewModel(
            useCases: .init(
                loadTrend: .init(repository: dependencies.tripRepository)
            ),
            mapper: RideDashboardMapperFactory.makeEfficiencyMapper(locale: .autoupdatingCurrent),
            session: dependencies.session
        )
        viewModel.setPreviewState(state)
        return viewModel
    }
}

@MainActor
enum RangeCardPreviewFactory {
    static func makeViewModel(state: DashboardRangeViewData) -> RangeCardViewModel {
        let dependencies = makePreviewTripDependencies()
        let viewModel = RangeCardViewModel(
            useCases: .init(
                loadHistory: .init(repository: dependencies.tripRepository)
            ),
            mapper: RideDashboardMapperFactory.makeRangeMapper(locale: .autoupdatingCurrent),
            session: dependencies.session
        )
        viewModel.setPreviewState(state)
        return viewModel
    }
}

@MainActor
enum RideDynamicsCardPreviewFactory {
    static func makeViewModel(state: DashboardRideDynamicsViewData) -> RideDynamicsCardViewModel {
        let viewModel = RideDynamicsCardViewModel(
            rideSession: PreviewRideSessionService(),
            vehicleSession: PreviewVehicleSessionService(),
            mapper: RideDashboardMapperFactory.makeRideDynamicsMapper(locale: .autoupdatingCurrent)
        )
        viewModel.setPreviewState(state)
        return viewModel
    }
}

@MainActor
enum SystemHealthCardPreviewFactory {
    static func makeViewModel(state: DashboardSystemHealthViewData) -> SystemHealthCardViewModel {
        let viewModel = SystemHealthCardViewModel(
            vehicleSession: PreviewVehicleSessionService(),
            mapper: RideDashboardMapperFactory.makeSystemHealthMapper(locale: .autoupdatingCurrent)
        )
        viewModel.setPreviewState(state)
        return viewModel
    }
}

@MainActor
enum BikeLockCardPreviewFactory {
    static func makeViewModel(state: BikeLockCardViewState = .init()) -> BikeLockCardViewModel {
        let repository = RideDashboardPreviewRepository()
        let settingsRepository = PreviewBikeLockSettingsRepository()
        let viewModel = BikeLockCardViewModel(
            prepareControl: .init(repository: repository),
            setLocked: .init(repository: repository),
            loadSettings: .init(repository: settingsRepository),
            saveSettings: .init(repository: settingsRepository),
            vehicleSession: PreviewVehicleSessionService(),
            credentialStore: PreviewBikeLockCredentialStore(),
            authenticator: PreviewBikeLockAuthenticator(),
            capabilityStore: PreviewBikeLockCapabilityStore(),
            allowsExperimentalControl: false
        )
        viewModel.setPreviewState(state)
        return viewModel
    }
}

private actor PreviewRideTripRepository: RideTripRepository {
    func prepare(context _: BikeSessionContext) -> RideTrip? { nil }
    func saveActiveTrip(_: RideTrip) -> Bool { true }
    func completeTrip(_: RideTrip, at _: Date) -> Bool { true }
    func loadCompletedTrips(vin _: String) -> [RideTrip] { [] }
    func promoteTemporaryIdentity(_: UUID, toVIN _: String) -> Bool { true }
}

@MainActor
private func makePreviewTripDependencies() -> PreviewTripDependencies {
    let tripRepository = PreviewRideTripRepository()
    return PreviewTripDependencies(
        session: PreviewRideSessionService(),
        tripRepository: tripRepository
    )
}

private struct PreviewTripDependencies {
    let session: PreviewRideSessionService
    let tripRepository: PreviewRideTripRepository
}

private actor PreviewRideSessionService: RideSessionService {
    private let snapshot = RideSessionSnapshot(vehicleIdentity: .temporary(UUID()))

    func observe() -> AsyncStream<RideSessionSnapshot> {
        AsyncStream { continuation in
            continuation.yield(snapshot)
            continuation.finish()
        }
    }

    func start() {}
    func stop() {}
    func persistCurrentTrip() {}
    func completeCurrentTrip() {}
    func flush() {}
    func togglePauseCurrentTrip() {}
    func resetCurrentTrip() {}
}

private actor PreviewVehicleSessionService: VehicleSessionService {
    func observe() -> AsyncStream<VehicleSessionSnapshot> {
        AsyncStream { $0.yield(.init()) }
    }

    func start() {}
    func stop() {}
    func refreshBikeStatus() {}
    func zeroBikeAttitude() {}
    func setBatteryHealthMonitoringRequired(_: Bool, consumerID _: UUID) {}
}

private actor PreviewBikeLockSettingsRepository: AppSettingsRepository {
    private var settings = AppSettings()

    func load() -> AppSettings { settings }
    func save(_ settings: AppSettings) { self.settings = settings }
    func observe() -> AsyncStream<AppSettings> { .init { $0.finish() } }
}

private actor PreviewBikeLockCredentialStore: BikeLockCredentialStoring {
    func save(pin _: String, for _: String) {}
    func verify(pin _: String, for _: String) -> Bool { true }
    func removePIN(for _: String) {}
}

private struct PreviewBikeLockAuthenticator: BikeLockAuthenticating {
    func authenticate() async throws -> Bool { true }
}

@MainActor
private final class PreviewBikeLockCapabilityStore: BikeLockCapabilityStateStoring {
    private(set) var currentState = BikeLockCapabilityState()

    func update(_ state: BikeLockCapabilityState) {
        currentState = state
    }

    func observe() -> AsyncStream<BikeLockCapabilityState> {
        .init { continuation in
            continuation.yield(currentState)
            continuation.finish()
        }
    }
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
