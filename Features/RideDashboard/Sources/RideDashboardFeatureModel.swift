import Combine

@MainActor
public final class RideDashboardFeatureModel: ObservableObject {
    let dashboardViewModel: RideDashboardViewModel
    let currentTripViewModel: CurrentTripCardViewModel
    let tripStatisticsViewModel: TripStatisticsCardViewModel
    let efficiencyViewModel: EfficiencyCardViewModel
    let rangeViewModel: RangeCardViewModel
    let systemHealthViewModel: SystemHealthCardViewModel
    let dynamicsViewModel: RideDynamicsCardViewModel
    let chargingViewModel: ChargingDashboardViewModel

    public init(
        dashboardViewModel: RideDashboardViewModel,
        currentTripViewModel: CurrentTripCardViewModel,
        tripStatisticsViewModel: TripStatisticsCardViewModel,
        efficiencyViewModel: EfficiencyCardViewModel,
        rangeViewModel: RangeCardViewModel,
        systemHealthViewModel: SystemHealthCardViewModel,
        dynamicsViewModel: RideDynamicsCardViewModel,
        chargingViewModel: ChargingDashboardViewModel
    ) {
        self.dashboardViewModel = dashboardViewModel
        self.currentTripViewModel = currentTripViewModel
        self.tripStatisticsViewModel = tripStatisticsViewModel
        self.efficiencyViewModel = efficiencyViewModel
        self.rangeViewModel = rangeViewModel
        self.systemHealthViewModel = systemHealthViewModel
        self.dynamicsViewModel = dynamicsViewModel
        self.chargingViewModel = chargingViewModel
    }

    func start() {
        dashboardViewModel.startObserving()
        rangeViewModel.start()
    }

    func stopPresentation() {
        dashboardViewModel.stopObserving()
        chargingViewModel.stop()
        currentTripViewModel.setIsVisible(false)
        tripStatisticsViewModel.stop()
        efficiencyViewModel.stop()
        rangeViewModel.stop()
        systemHealthViewModel.setIsVisible(false)
        dynamicsViewModel.setIsVisible(false)
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
        rangeViewModel.setIsVisible(selection.isRangeVisible(in: centerMode))
        systemHealthViewModel.setIsVisible(selection.isSystemHealthVisible(in: centerMode))
        dynamicsViewModel.setIsVisible(selection.isDynamicsVisible(in: centerMode))
    }
}
