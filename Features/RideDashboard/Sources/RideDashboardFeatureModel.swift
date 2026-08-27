import Combine

@MainActor
public final class RideDashboardFeatureModel: ObservableObject {
    let dashboardViewModel: RideDashboardViewModel
    let currentTripViewModel: CurrentTripCardViewModel
    let tripStatisticsViewModel: TripStatisticsCardViewModel
    let efficiencyViewModel: EfficiencyCardViewModel
    let chargingViewModel: ChargingDashboardViewModel

    public init(
        dashboardViewModel: RideDashboardViewModel,
        currentTripViewModel: CurrentTripCardViewModel,
        tripStatisticsViewModel: TripStatisticsCardViewModel,
        efficiencyViewModel: EfficiencyCardViewModel,
        chargingViewModel: ChargingDashboardViewModel
    ) {
        self.dashboardViewModel = dashboardViewModel
        self.currentTripViewModel = currentTripViewModel
        self.tripStatisticsViewModel = tripStatisticsViewModel
        self.efficiencyViewModel = efficiencyViewModel
        self.chargingViewModel = chargingViewModel
    }

    func start() {
        dashboardViewModel.startObserving()
    }

    func stopPresentation() {
        dashboardViewModel.stopObserving()
        chargingViewModel.stop()
        currentTripViewModel.setIsVisible(false)
        tripStatisticsViewModel.stop()
        efficiencyViewModel.stop()
    }

    func synchronizeCardLifecycles(
        centerMode: RideDashboardViewState.CenterMode,
        selection: DashboardCardSelectionState
    ) {
        if centerMode == .charging {
            chargingViewModel.start()
        } else {
            chargingViewModel.stop()
        }

        let isCurrentTripVisible = selection.isCurrentTripVisible(in: centerMode)
        currentTripViewModel.setIsVisible(
            isCurrentTripVisible && selection.currentTripPage == .current
        )
        tripStatisticsViewModel.setIsVisible(
            isCurrentTripVisible && selection.currentTripPage == .statistics
        )
        efficiencyViewModel.setIsVisible(
            selection.isEfficiencyVisible(in: centerMode),
            page: selection.efficiencyPage
        )
    }
}
