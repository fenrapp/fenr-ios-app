import Observation
import RideSession
import RideSessionDomain
import SettingsDomain

@MainActor
@Observable
public final class TripStatisticsCardViewModel {
    public private(set) var viewState = DashboardTripStatisticsViewData(
        showsStatistics: false, isLoading: true,
        accessibilityLabel: rideDashboardLocalized(.rideDashboardTripStatisticsLoading)
    )

    private let useCases: TripStatisticsCardUseCases
    private let mapper: TripStatisticsCardMapper
    private let session: any RideSessionService
    @ObservationIgnored private var measurementSystem = MeasurementSystem.metric
    @ObservationIgnored private var statistics = RideTripStatistics()
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var sessionTask: Task<Void, Never>?
    @ObservationIgnored private var activeVIN: String?
    @ObservationIgnored private var requestedRevision = 0
    @ObservationIgnored private var loadedKey: DashboardRideHistoryKey?
    @ObservationIgnored private var failedKey: DashboardRideHistoryKey?
    @ObservationIgnored private var loadGeneration = 0
    @ObservationIgnored private var isVisible = false

    public init(
        useCases: TripStatisticsCardUseCases,
        mapper: TripStatisticsCardMapper,
        session: any RideSessionService
    ) {
        self.useCases = useCases
        self.mapper = mapper
        self.session = session
    }

    deinit {
        loadTask?.cancel()
        sessionTask?.cancel()
    }

    func setIsVisible(_ isVisible: Bool) {
        if isVisible, !self.isVisible { failedKey = nil }
        self.isVisible = isVisible
        guard isVisible else {
            pauseObservation()
            return
        }
        startObservingSessionIfNeeded()
        loadIfNeeded()
    }

    func stop() {
        isVisible = false
        pauseObservation()
        loadedKey = nil
        failedKey = nil
        statistics = .init()
    }

    func pause() {
        isVisible = false
        pauseObservation()
    }

    private func pauseObservation() {
        loadGeneration += 1
        loadTask?.cancel()
        loadTask = nil
        sessionTask?.cancel()
        sessionTask = nil
    }

    func retryHistory() {
        guard loadTask == nil else { return }
        failedKey = nil
        loadIfNeeded()
    }

#if DEBUG
    var historyLoadTaskForTesting: Task<Void, Never>? { loadTask }

    func setPreviewState(_ viewState: DashboardTripStatisticsViewData) {
        self.viewState = viewState
    }
#endif
}

private extension TripStatisticsCardViewModel {
    func loadIfNeeded() {
        guard isVisible, let activeVIN, loadTask == nil else { return }
        let key = DashboardRideHistoryKey(vin: activeVIN, revision: requestedRevision)
        guard loadedKey != key, failedKey != key else { return }
        failedKey = nil
        let loadStatistics = useCases.loadStatistics
        let generation = loadGeneration
        if loadedKey == nil {
            viewState = DashboardTripStatisticsViewData(
                showsStatistics: false, isLoading: true,
                accessibilityLabel: rideDashboardLocalized(.rideDashboardTripStatisticsLoading)
            )
        }
        loadTask = Task { [weak self] in
            do {
                let statistics = try await loadStatistics.execute(vin: activeVIN)
                guard !Task.isCancelled, self?.loadGeneration == generation else { return }
                self?.finishLoading(statistics, key: key)
            } catch {
                guard !Task.isCancelled, self?.loadGeneration == generation else { return }
                self?.failLoading(key: key)
            }
        }
    }

    func finishLoading(_ statistics: RideTripStatistics, key: DashboardRideHistoryKey) {
        guard acceptsCompletion(for: key) else { return }
        self.statistics = statistics
        loadedKey = key
        loadTask = nil
        render()
        loadIfNeeded()
    }

    func failLoading(key: DashboardRideHistoryKey) {
        guard acceptsCompletion(for: key) else { return }
        failedKey = key
        loadTask = nil
        render()
        loadIfNeeded()
    }

    func acceptsCompletion(for key: DashboardRideHistoryKey) -> Bool {
        guard key.vin == activeVIN, key.revision == requestedRevision else {
            loadTask = nil
            loadIfNeeded()
            return false
        }
        return true
    }

    func render() {
        guard isVisible else { return }
        if loadedKey == nil, failedKey == nil {
            viewState = .init(
                showsStatistics: false, isLoading: true,
                accessibilityLabel: rideDashboardLocalized(.rideDashboardTripStatisticsLoading)
            )
            return
        }
        viewState = mapper.map(
            statistics,
            measurementSystem: measurementSystem,
            historyReadFailed: failedKey != nil,
            hasLoadedHistory: loadedKey != nil
        )
    }

    func startObservingSessionIfNeeded() {
        guard sessionTask == nil else { return }
        sessionTask = Task { [weak self, session] in
            let stream = await session.observe()
            for await snapshot in stream {
                guard !Task.isCancelled else { return }
                self?.receive(snapshot)
            }
        }
    }

    func receive(_ snapshot: RideSessionSnapshot) {
        measurementSystem = snapshot.measurementSystem
        let vin = snapshot.vehicleIdentity.confirmedVIN
        if vin != activeVIN {
            activeVIN = vin
            requestedRevision = snapshot.historyRevision
            loadedKey = nil
            failedKey = nil
            statistics = .init()
            loadGeneration += 1
            loadTask?.cancel()
            loadTask = nil
        } else {
            requestedRevision = max(requestedRevision, snapshot.historyRevision)
        }
        render()
        guard snapshot.isCanonicalTelemetryAvailable else { return }
        loadIfNeeded()
    }
}
