import Foundation
@testable import RideDashboard
import RideSession
import RideSessionDomain

@MainActor
struct DashboardHistoryCardFixture {
    let repository: CurrentTripCardTripRepository
    let session: TestRideSessionService
    let show: () -> Void
    let hide: () -> Void
    let stop: () -> Void
    let retry: () -> Void
    let error: () -> String?
    let displayedHistory: () -> String
    let loadTask: () -> Task<Void, Never>?
    let measurementUnit: () -> String
    let historyIsLoading: () -> Bool

    init(kind: DashboardHistoryCardKind) {
        repository = CurrentTripCardTripRepository(completedTrips: [DashboardHistoryCardData.trip()])
        session = TestRideSessionService(snapshot: DashboardHistoryCardData.snapshot())
        switch kind {
        case .range:
            let model = RangeCardViewModel(
                useCases: .init(loadHistory: .init(repository: repository)),
                mapper: .init(locale: Locale(identifier: "en_GB"), estimator: RideRangeEstimator()),
                session: session
            )
            show = { model.setIsVisible(true) }
            hide = model.pause
            stop = model.stop
            retry = model.retryHistory
            error = { model.viewState.historyError }
            loadTask = { model.historyLoadTaskForTesting }
            displayedHistory = { model.viewState.typicalRangeText }
            measurementUnit = { model.viewState.distanceUnitText }
            historyIsLoading = { model.viewState.isLoadingHistory }
        case .efficiency:
            let model = EfficiencyCardViewModel(
                useCases: .init(loadTrend: .init(repository: repository)),
                mapper: .init(locale: Locale(identifier: "en_GB")),
                session: session
            )
            show = { model.setIsVisible(true, page: .trend) }
            hide = model.pause
            stop = model.stop
            retry = model.retryHistory
            error = { model.viewState.historyError }
            loadTask = { model.historyLoadTaskForTesting }
            displayedHistory = { String(model.viewState.trendPoints.count) }
            measurementUnit = { model.viewState.unitText }
            historyIsLoading = { model.viewState.trendIsLoading }
        case .statistics:
            let model = TripStatisticsCardViewModel(
                useCases: .init(loadStatistics: .init(repository: repository, aggregator: .init())),
                mapper: RideDashboardMapperFactory.makeTripStatisticsMapper(locale: Locale(identifier: "en_GB")),
                session: session
            )
            show = { model.setIsVisible(true) }
            hide = model.pause
            stop = model.stop
            retry = model.retryHistory
            error = { model.viewState.historyError }
            loadTask = { model.historyLoadTaskForTesting }
            displayedHistory = { model.viewState.totalDistance.valueText }
            measurementUnit = { model.viewState.totalDistance.unit }
            historyIsLoading = { model.viewState.isLoading && !model.viewState.showsStatistics }
        }
    }

}
