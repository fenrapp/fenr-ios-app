import Foundation
import Observation
import RideSession
import RideSessionDomain

@MainActor
@Observable
public final class RangeCardViewModel {
    public private(set) var viewState = DashboardRangeViewData()
    public private(set) var summary: DashboardRangeViewData.Summary?

    private let useCases: RangeCardUseCases
    private let mapper: RangeCardMapper
    private let session: any RideSessionService
    @ObservationIgnored private var snapshot = RideSessionSnapshot(
        vehicleIdentity: .temporary(UUID()),
        isCanonicalTelemetryAvailable: false
    )
    @ObservationIgnored private var historicalTrips: [RideTrip] = []
    @ObservationIgnored private var loadedKey: DashboardRideHistoryKey?
    @ObservationIgnored private var failedKey: DashboardRideHistoryKey?
    @ObservationIgnored private var loadGeneration = 0
    @ObservationIgnored private var isStarted = false
    @ObservationIgnored private var isVisible = false
    @ObservationIgnored private var historyIsLoading = false
    @ObservationIgnored private var sessionTask: Task<Void, Never>?
    @ObservationIgnored private var loadTask: Task<Void, Never>?

    public init(
        useCases: RangeCardUseCases,
        mapper: RangeCardMapper,
        session: any RideSessionService
    ) {
        self.useCases = useCases
        self.mapper = mapper
        self.session = session
    }

    deinit {
        sessionTask?.cancel()
        loadTask?.cancel()
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        observeSessionIfNeeded()
        loadHistoryIfNeeded()
        render()
    }

    func setIsVisible(_ isVisible: Bool) {
        if isVisible, !self.isVisible { failedKey = nil }
        self.isVisible = isVisible
        guard isVisible else { return }
        start()
        loadHistoryIfNeeded()
        render()
    }

    func stop() {
        isStarted = false
        isVisible = false
        stopPublishing()
        loadedKey = nil
        failedKey = nil
        historicalTrips = []
        summary = nil
    }

    func pause() {
        isStarted = false
        isVisible = false
        stopPublishing()
    }

    func retryHistory() {
        guard loadTask == nil else { return }
        failedKey = nil
        loadHistoryIfNeeded()
    }

#if DEBUG
    var historyLoadTaskForTesting: Task<Void, Never>? { loadTask }

    var isObservingForTesting: Bool { sessionTask != nil }

    func setPreviewState(_ viewState: DashboardRangeViewData) {
        isStarted = true
        self.viewState = viewState
        summary = viewState.summary
    }
#endif
}

private extension RangeCardViewModel {
    func observeSessionIfNeeded() {
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
        let changedVIN = self.snapshot.vehicleIdentity.confirmedVIN != snapshot.vehicleIdentity.confirmedVIN
        if changedVIN {
            self.snapshot = snapshot
            loadedKey = nil
            failedKey = nil
            historicalTrips = []
            loadGeneration += 1
            loadTask?.cancel()
            loadTask = nil
            historyIsLoading = false
            render()
        }
        guard snapshot.isCanonicalTelemetryAvailable else { return }
        self.snapshot = snapshot
        loadHistoryIfNeeded()
        render()
    }

    func loadHistoryIfNeeded() {
        guard isStarted,
              let vin = snapshot.vehicleIdentity.confirmedVIN,
              loadTask == nil else { return }
        let key = DashboardRideHistoryKey(vin: vin, revision: snapshot.historyRevision)
        guard loadedKey != key, failedKey != key else { return }
        failedKey = nil
        historyIsLoading = historicalTrips.isEmpty
        render()
        let loadHistory = useCases.loadHistory
        let generation = loadGeneration
        loadTask = Task { [weak self] in
            do {
                let trips = try await loadHistory.execute(vin: vin)
                guard !Task.isCancelled, self?.loadGeneration == generation else { return }
                self?.finishLoading(trips, key: key)
            } catch {
                guard !Task.isCancelled, self?.loadGeneration == generation else { return }
                self?.failLoading(key: key)
            }
        }
    }

    func finishLoading(_ trips: [RideTrip], key: DashboardRideHistoryKey) {
        guard acceptsCompletion(for: key) else { return }
        historicalTrips = trips
        loadedKey = key
        historyIsLoading = false
        loadTask = nil
        render()
        loadHistoryIfNeeded()
    }

    func failLoading(key: DashboardRideHistoryKey) {
        guard acceptsCompletion(for: key) else { return }
        failedKey = key
        historyIsLoading = false
        loadTask = nil
        render()
        loadHistoryIfNeeded()
    }

    func acceptsCompletion(for key: DashboardRideHistoryKey) -> Bool {
        guard key.vin == snapshot.vehicleIdentity.confirmedVIN, key.revision == snapshot.historyRevision else {
            loadTask = nil
            loadHistoryIfNeeded()
            return false
        }
        return true
    }

    func render() {
        let nextState = mapper.map(
            snapshot: snapshot,
            historicalTrips: historicalTrips,
            historyIsLoading: historyIsLoading,
            historyReadFailed: failedKey != nil,
            hasLoadedHistory: loadedKey != nil
        )
        if nextState.summary != summary {
            summary = nextState.summary
        }
        guard isVisible else { return }
        guard nextState != viewState else { return }
        viewState = nextState
    }

    func stopPublishing() {
        loadGeneration += 1
        sessionTask?.cancel()
        sessionTask = nil
        loadTask?.cancel()
        loadTask = nil
        historyIsLoading = false
    }
}
