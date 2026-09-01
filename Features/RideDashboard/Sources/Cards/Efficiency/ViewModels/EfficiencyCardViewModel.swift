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
        trendTrips = []
    }

    func pause() {
        isVisible = false
        stopPublishing()
    }

#if DEBUG
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
        guard snapshot.isCanonicalTelemetryAvailable else { return }
        let previousVIN = self.snapshot.vehicleIdentity.confirmedVIN
        self.snapshot = snapshot
        if previousVIN != snapshot.vehicleIdentity.confirmedVIN {
            loadedKey = nil
            trendTrips = []
            loadTask?.cancel()
            loadTask = nil
        }
        loadTrendIfNeeded()
        render()
    }

    func loadTrendIfNeeded() {
        guard isVisible,
              selectedPage == .trend,
              let vin = snapshot.vehicleIdentity.confirmedVIN,
              loadTask == nil else { return }
        let key = DashboardRideHistoryKey(vin: vin, revision: snapshot.historyRevision)
        guard loadedKey != key else { return }
        trendIsLoading = trendTrips.isEmpty
        render()
        let loadTrend = useCases.loadTrend
        loadTask = Task { [weak self] in
            let trips = await loadTrend.execute(vin: vin)
            guard !Task.isCancelled else { return }
            self?.finishLoading(trips, key: key)
        }
    }

    func finishLoading(_ trips: [RideTrip], key: DashboardRideHistoryKey) {
        trendTrips = trips
        loadedKey = key
        trendIsLoading = false
        loadTask = nil
        render()
        loadTrendIfNeeded()
    }

    func render() {
        guard isVisible else { return }
        viewState = mapper.map(
            snapshot: snapshot,
            trendTrips: trendTrips,
            trendIsLoading: trendIsLoading,
            measurementSystem: snapshot.measurementSystem
        )
    }

    func stopPublishing() {
        sessionTask?.cancel()
        sessionTask = nil
        loadTask?.cancel()
        loadTask = nil
        trendIsLoading = false
    }
}
