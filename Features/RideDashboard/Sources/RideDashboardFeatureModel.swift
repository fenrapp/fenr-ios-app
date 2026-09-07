@MainActor
public final class RideDashboardFeatureModel {
    let dashboardViewModel: RideDashboardViewModel
    let deviceBatteryViewModel: DashboardDeviceBatteryViewModel
    let currentTripViewModel: CurrentTripCardViewModel
    let tripStatisticsViewModel: TripStatisticsCardViewModel
    let efficiencyViewModel: EfficiencyCardViewModel
    let rangeViewModel: RangeCardViewModel
    let systemHealthViewModel: SystemHealthCardViewModel
    let dynamicsViewModel: RideDynamicsCardViewModel
    let chargingViewModel: ChargingDashboardViewModel
    let bikeLockViewModel: BikeLockCardViewModel
    private var isStarted = false
    private var isPresentationActive = false
    private let cardLifecycle: RideDashboardCardLifecycleController

    public init(
        dashboardViewModel: RideDashboardViewModel,
        deviceBatteryViewModel: DashboardDeviceBatteryViewModel,
        currentTripViewModel: CurrentTripCardViewModel,
        tripStatisticsViewModel: TripStatisticsCardViewModel,
        efficiencyViewModel: EfficiencyCardViewModel,
        rangeViewModel: RangeCardViewModel,
        systemHealthViewModel: SystemHealthCardViewModel,
        dynamicsViewModel: RideDynamicsCardViewModel,
        chargingViewModel: ChargingDashboardViewModel,
        bikeLockViewModel: BikeLockCardViewModel,
        cardLifecycle: RideDashboardCardLifecycleController
    ) {
        self.dashboardViewModel = dashboardViewModel
        self.deviceBatteryViewModel = deviceBatteryViewModel
        self.currentTripViewModel = currentTripViewModel
        self.tripStatisticsViewModel = tripStatisticsViewModel
        self.efficiencyViewModel = efficiencyViewModel
        self.rangeViewModel = rangeViewModel
        self.systemHealthViewModel = systemHealthViewModel
        self.dynamicsViewModel = dynamicsViewModel
        self.chargingViewModel = chargingViewModel
        self.bikeLockViewModel = bikeLockViewModel
        self.cardLifecycle = cardLifecycle
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        cardLifecycle.receiveContinuity(dashboardViewModel.viewState.continuityPhase)
    }

    func setPresentationActive(_ isActive: Bool) {
        if isActive, !isStarted {
            start()
        }
        guard isPresentationActive != isActive else { return }
        isPresentationActive = isActive
        if isActive {
            resumePresentation()
        } else {
            pausePresentation()
        }
    }

    func invalidateSession() {
        setPresentationActive(false)
        dashboardViewModel.invalidateSession()
        cardLifecycle.invalidate()
        isStarted = false
    }

    private func resumePresentation() {
        cardLifecycle.setPresentationActive(true)
        dashboardViewModel.startObserving()
        deviceBatteryViewModel.start()
    }

    private func pausePresentation() {
        dashboardViewModel.pausePresentation()
        deviceBatteryViewModel.stop()
        cardLifecycle.setPresentationActive(false)
    }

    func synchronizeCardLifecycles(
        centerMode: RideDashboardViewState.CenterMode,
        selection: DashboardCardSelectionState
    ) {
        cardLifecycle.synchronize(centerMode: centerMode, selection: selection)
    }
}
