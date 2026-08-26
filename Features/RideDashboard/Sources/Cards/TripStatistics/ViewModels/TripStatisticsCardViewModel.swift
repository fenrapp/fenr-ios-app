import Combine
import RideSessionDomain
import SettingsDomain

@MainActor
public final class TripStatisticsCardViewModel: ObservableObject {
    @Published public private(set) var viewState = DashboardTripStatisticsViewData()

    private let useCases: TripStatisticsCardUseCases
    private let mapper: TripStatisticsCardMapper
    private var settings = AppSettings()
    private var statistics = RideTripStatistics()
    private var loadTask: Task<Void, Never>?
    private var settingsTask: Task<Void, Never>?
    private var requestedRevision = 0
    private var loadedRevision: Int?
    private var isVisible = false

    public init(
        useCases: TripStatisticsCardUseCases,
        mapper: TripStatisticsCardMapper
    ) {
        self.useCases = useCases
        self.mapper = mapper
    }

    deinit {
        loadTask?.cancel()
        settingsTask?.cancel()
    }

    public func setIsVisible(_ isVisible: Bool) {
        self.isVisible = isVisible
        guard isVisible else { return }
        startObservingSettingsIfNeeded()
        loadIfNeeded()
    }

    public func invalidate() {
        requestedRevision += 1
        loadIfNeeded()
    }

    public func stop() {
        isVisible = false
        loadTask?.cancel()
        loadTask = nil
        settingsTask?.cancel()
        settingsTask = nil
    }

#if DEBUG
    func setPreviewState(_ viewState: DashboardTripStatisticsViewData) {
        self.viewState = viewState
    }
#endif
}

private extension TripStatisticsCardViewModel {
    func startObservingSettingsIfNeeded() {
        guard settingsTask == nil else { return }
        let observeSettings = useCases.observeSettings
        settingsTask = Task { [weak self] in
            let stream = await observeSettings.execute()
            for await settings in stream {
                guard !Task.isCancelled else { return }
                self?.settings = settings
                self?.render()
            }
        }
    }

    func loadIfNeeded() {
        guard isVisible, loadTask == nil, loadedRevision != requestedRevision else { return }
        let revision = requestedRevision
        let loadStatistics = useCases.loadStatistics
        if loadedRevision == nil {
            viewState = DashboardTripStatisticsViewData(isLoading: true)
        }
        loadTask = Task { [weak self] in
            let statistics = await loadStatistics.execute()
            guard !Task.isCancelled else { return }
            self?.finishLoading(statistics, revision: revision)
        }
    }

    func finishLoading(_ statistics: RideTripStatistics, revision: Int) {
        self.statistics = statistics
        loadedRevision = revision
        loadTask = nil
        render()
        loadIfNeeded()
    }

    func render() {
        guard loadedRevision != nil else { return }
        viewState = mapper.map(
            statistics,
            measurementSystem: settings.measurementSystem
        )
    }
}
