import Combine
import Foundation
import RideSession
import RideSessionDomain

@MainActor
public final class RangeCardViewModel: ObservableObject {
    @Published public private(set) var viewState = DashboardRangeViewData()
    @Published public private(set) var summary: DashboardRangeViewData.Summary?

    private let useCases: RangeCardUseCases
    private let mapper: RangeCardMapper
    private let session: any RideSessionService
    private var snapshot = RideSessionSnapshot(
        vehicleIdentity: .temporary(UUID()),
        isCanonicalTelemetryAvailable: false
    )
    private var historicalTrips: [RideTrip] = []
    private var loadedKey: DashboardRideHistoryKey?
    private var isStarted = false
    private var isVisible = false
    private var historyIsLoading = false
    private var sessionTask: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?

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
        self.isVisible = isVisible
        guard isVisible else { return }
        start()
        render()
    }

    func stop() {
        isStarted = false
        isVisible = false
        stopPublishing()
        loadedKey = nil
        historicalTrips = []
        summary = nil
    }

    func pause() {
        isStarted = false
        isVisible = false
        stopPublishing()
    }

#if DEBUG
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
        guard snapshot.isCanonicalTelemetryAvailable else { return }
        let previousVIN = self.snapshot.vehicleIdentity.confirmedVIN
        self.snapshot = snapshot
        if previousVIN != snapshot.vehicleIdentity.confirmedVIN {
            loadedKey = nil
            historicalTrips = []
            loadTask?.cancel()
            loadTask = nil
        }
        loadHistoryIfNeeded()
        render()
    }

    func loadHistoryIfNeeded() {
        guard isStarted,
              let vin = snapshot.vehicleIdentity.confirmedVIN,
              loadTask == nil else { return }
        let key = DashboardRideHistoryKey(vin: vin, revision: snapshot.historyRevision)
        guard loadedKey != key else { return }
        historyIsLoading = historicalTrips.isEmpty
        render()
        let loadHistory = useCases.loadHistory
        loadTask = Task { [weak self] in
            let trips = await loadHistory.execute(vin: vin)
            guard !Task.isCancelled else { return }
            self?.finishLoading(trips, key: key)
        }
    }

    func finishLoading(_ trips: [RideTrip], key: DashboardRideHistoryKey) {
        historicalTrips = trips
        loadedKey = key
        historyIsLoading = false
        loadTask = nil
        render()
        loadHistoryIfNeeded()
    }

    func render() {
        let nextState = mapper.map(
            snapshot: snapshot,
            historicalTrips: historicalTrips,
            historyIsLoading: historyIsLoading
        )
        if nextState.summary != summary {
            summary = nextState.summary
        }
        guard isVisible else { return }
        guard nextState != viewState else { return }
        viewState = nextState
    }

    func stopPublishing() {
        sessionTask?.cancel()
        sessionTask = nil
        loadTask?.cancel()
        loadTask = nil
        historyIsLoading = false
    }
}
