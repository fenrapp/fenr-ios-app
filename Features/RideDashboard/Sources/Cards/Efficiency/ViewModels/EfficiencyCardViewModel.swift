import Combine
import Foundation
import RideSession
import RideSessionDomain

@MainActor
public final class EfficiencyCardViewModel: ObservableObject {
    @Published public private(set) var viewState = DashboardEfficiencyViewData()

    private let useCases: EfficiencyCardUseCases
    private let mapper: EfficiencyCardMapper
    private let session: any RideSessionService
    private var snapshot = RideSessionSnapshot(
        vehicleIdentity: .temporary(UUID()),
        isCanonicalTelemetryAvailable: false
    )
    private var trendTrips: [RideTrip] = []
    private var selectedPage = EfficiencyDashboardPage.live
    private var loadedKey: DashboardRideHistoryKey?
    private var failedKey: DashboardRideHistoryKey?
    private var loadGeneration = 0
    private var isVisible = false
    private var trendIsLoading = false
    private var sessionTask: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?

    public init(
        useCases: EfficiencyCardUseCases,
        mapper: EfficiencyCardMapper,
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

    func setIsVisible(_ isVisible: Bool, page: EfficiencyDashboardPage) {
        if isVisible, !self.isVisible || page != selectedPage { failedKey = nil }
        self.isVisible = isVisible
        selectedPage = page
        guard isVisible else {
            stopPublishing()
            return
        }
        observeSessionIfNeeded()
        loadTrendIfNeeded()
        render()
    }

    func stop() {
        isVisible = false
        stopPublishing()
        loadedKey = nil
        failedKey = nil
        trendTrips = []
    }

    func pause() {
        isVisible = false
        stopPublishing()
    }

    func retryHistory() {
        guard loadTask == nil else { return }
        failedKey = nil
        loadTrendIfNeeded()
    }

#if DEBUG
    var historyLoadTaskForTesting: Task<Void, Never>? { loadTask }

    func setPreviewState(_ viewState: DashboardEfficiencyViewData) {
        self.viewState = viewState
    }
#endif
}

private extension EfficiencyCardViewModel {
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
            trendTrips = []
            loadGeneration += 1
            loadTask?.cancel()
            loadTask = nil
            trendIsLoading = false
            render()
        }
        guard snapshot.isCanonicalTelemetryAvailable else { return }
        self.snapshot = snapshot
        loadTrendIfNeeded()
        render()
    }

    func loadTrendIfNeeded() {
        guard isVisible,
              selectedPage == .trend,
              let vin = snapshot.vehicleIdentity.confirmedVIN,
              loadTask == nil else { return }
        let key = DashboardRideHistoryKey(vin: vin, revision: snapshot.historyRevision)
        guard loadedKey != key, failedKey != key else { return }
        failedKey = nil
        trendIsLoading = trendTrips.isEmpty
        render()
        let loadTrend = useCases.loadTrend
        let generation = loadGeneration
        loadTask = Task { [weak self] in
            do {
                let trips = try await loadTrend.execute(vin: vin)
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
        trendTrips = trips
        loadedKey = key
        trendIsLoading = false
        loadTask = nil
        render()
        loadTrendIfNeeded()
    }

    func failLoading(key: DashboardRideHistoryKey) {
        guard acceptsCompletion(for: key) else { return }
        failedKey = key
        trendIsLoading = false
        loadTask = nil
        render()
        loadTrendIfNeeded()
    }

    func acceptsCompletion(for key: DashboardRideHistoryKey) -> Bool {
        guard key.vin == snapshot.vehicleIdentity.confirmedVIN, key.revision == snapshot.historyRevision else {
            loadTask = nil
            loadTrendIfNeeded()
            return false
        }
        return true
    }

    func render() {
        guard isVisible else { return }
        viewState = mapper.map(
            snapshot: snapshot,
            trendTrips: trendTrips,
            trendIsLoading: trendIsLoading || (
                loadedKey == nil && failedKey == nil && snapshot.vehicleIdentity.confirmedVIN != nil
            ),
            measurementSystem: snapshot.measurementSystem,
            historyReadFailed: failedKey != nil,
            hasLoadedHistory: loadedKey != nil
        )
    }

    func stopPublishing() {
        loadGeneration += 1
        sessionTask?.cancel()
        sessionTask = nil
        loadTask?.cancel()
        loadTask = nil
        trendIsLoading = false
    }
}
