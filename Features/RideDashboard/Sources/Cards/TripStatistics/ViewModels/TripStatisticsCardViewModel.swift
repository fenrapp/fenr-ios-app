import Combine
import RideSession
import RideSessionDomain
import SettingsDomain

@MainActor
public final class TripStatisticsCardViewModel: ObservableObject {
    @Published public private(set) var viewState = DashboardTripStatisticsViewData()

    private let useCases: TripStatisticsCardUseCases
    private let mapper: TripStatisticsCardMapper
    private let session: any RideSessionService
    private var measurementSystem = MeasurementSystem.metric
    private var statistics = RideTripStatistics()
    private var loadTask: Task<Void, Never>?
    private var sessionTask: Task<Void, Never>?
    private var activeVIN: String?
    private var requestedRevision = 0
    private var loadedKey: DashboardRideHistoryKey?
    private var isVisible = false

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
        statistics = .init()
    }

    private func pauseObservation() {
        loadTask?.cancel()
        loadTask = nil
        sessionTask?.cancel()
        sessionTask = nil
    }

#if DEBUG
    func setPreviewState(_ viewState: DashboardTripStatisticsViewData) {
        self.viewState = viewState
    }
#endif
}

private extension TripStatisticsCardViewModel {
    func loadIfNeeded() {
        guard isVisible, let activeVIN, loadTask == nil else { return }
        let key = DashboardRideHistoryKey(vin: activeVIN, revision: requestedRevision)
        guard loadedKey != key else { return }
        let loadStatistics = useCases.loadStatistics
        if loadedKey == nil {
            viewState = DashboardTripStatisticsViewData(isLoading: true)
        }
        loadTask = Task { [weak self] in
            let statistics = await loadStatistics.execute(vin: activeVIN)
            guard !Task.isCancelled else { return }
            self?.finishLoading(statistics, key: key)
        }
    }

    func finishLoading(_ statistics: RideTripStatistics, key: DashboardRideHistoryKey) {
        self.statistics = statistics
        loadedKey = key
        loadTask = nil
        render()
        loadIfNeeded()
    }

    func render() {
        guard isVisible, loadedKey != nil else { return }
        viewState = mapper.map(
            statistics,
            measurementSystem: measurementSystem
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
            loadTask?.cancel()
            loadTask = nil
        } else {
            requestedRevision = max(requestedRevision, snapshot.historyRevision)
        }
        loadIfNeeded()
    }
}
