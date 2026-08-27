import Combine
import Foundation
import RideSession
import RideSessionDomain

@MainActor
public final class RangeCardViewModel: ObservableObject {
    @Published public private(set) var viewState = DashboardRangeViewData()

    private let useCases: RangeCardUseCases
    private let mapper: RangeCardMapper
    private let session: any RideSessionService
    private var snapshot = RideSessionSnapshot(vehicleIdentity: .temporary(UUID()))
    private var historicalTrips: [RideTrip] = []
    private var loadedKey: DashboardRideHistoryKey?
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

    func setIsVisible(_ isVisible: Bool) {
        self.isVisible = isVisible
        guard isVisible else {
            stopPublishing()
            return
        }
        observeSessionIfNeeded()
        loadHistoryIfNeeded()
        render()
    }

    func stop() {
        isVisible = false
        stopPublishing()
        loadedKey = nil
        historicalTrips = []
    }

#if DEBUG
    func setPreviewState(_ viewState: DashboardRangeViewData) {
        self.viewState = viewState
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
        guard isVisible,
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
        guard isVisible else { return }
        let nextState = mapper.map(
            snapshot: snapshot,
            historicalTrips: historicalTrips,
            historyIsLoading: historyIsLoading
        )
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
