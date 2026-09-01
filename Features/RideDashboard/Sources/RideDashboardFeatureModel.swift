import Combine

@MainActor
public final class RideDashboardFeatureModel: ObservableObject {
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
    private var continuityObservation: AnyCancellable?
    private var latestCenterMode: RideDashboardViewState.CenterMode?
    private var latestSelection: DashboardCardSelectionState?

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
        bikeLockViewModel: BikeLockCardViewModel
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
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        continuityObservation = dashboardViewModel.$viewState
            .map(\.continuityPhase)
            .removeDuplicates()
            .sink { [weak self] phase in
                self?.applyCardLifecycles(for: phase)
            }
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
        continuityObservation?.cancel()
        continuityObservation = nil
        latestCenterMode = nil
        latestSelection = nil
        isStarted = false
    }

    private func resumePresentation() {
        dashboardViewModel.startObserving()
        deviceBatteryViewModel.start()
    }

    private func pausePresentation() {
        dashboardViewModel.pausePresentation()
        deviceBatteryViewModel.stop()
        chargingViewModel.suspend()
        currentTripViewModel.setIsVisible(false)
        tripStatisticsViewModel.pause()
        efficiencyViewModel.pause()
        rangeViewModel.pause()
        systemHealthViewModel.setIsVisible(false)
        dynamicsViewModel.setIsVisible(false)
        bikeLockViewModel.suspend()
    }

    func synchronizeCardLifecycles(
        centerMode: RideDashboardViewState.CenterMode,
        selection: DashboardCardSelectionState
    ) {
        latestCenterMode = centerMode
        latestSelection = selection
        applyCardLifecycles(for: dashboardViewModel.viewState.continuityPhase)
    }

    private func applyCardLifecycles(for phase: RideDashboardContinuityPhase) {
        guard isPresentationActive else { return }
        switch phase {
        case .live:
            guard let latestCenterMode, let latestSelection else { return }
            rangeViewModel.start()
            bikeLockViewModel.start()
            synchronizeLiveCardLifecycles(
                centerMode: latestCenterMode,
                selection: latestSelection
            )
        case .recovering:
            pauseRecoverySensitiveCards()
            guard let latestCenterMode, let latestSelection else {
                systemHealthViewModel.setIsVisible(false)
                return
            }
            systemHealthViewModel.setIsVisible(
                latestSelection.isSystemHealthVisible(in: latestCenterMode)
            )
        case .cold, .terminal:
            pauseAllCards()
        }
    }

    private func synchronizeLiveCardLifecycles(
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

    private func pauseRecoverySensitiveCards() {
        currentTripViewModel.setIsVisible(false)
        tripStatisticsViewModel.pause()
        efficiencyViewModel.pause()
        rangeViewModel.pause()
        dynamicsViewModel.setIsVisible(false)
    }

    private func pauseAllCards() {
        chargingViewModel.suspend()
        pauseRecoverySensitiveCards()
        systemHealthViewModel.setIsVisible(false)
        bikeLockViewModel.suspend()
    }
}
