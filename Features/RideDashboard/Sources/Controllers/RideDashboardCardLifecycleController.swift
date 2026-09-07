@MainActor
public final class RideDashboardCardLifecycleController {
    private let dependencies: RideDashboardCardLifecycleDependencies
    private var phase = RideDashboardContinuityPhase.cold
    private var isPresentationActive = false
    private var latestCenterMode: RideDashboardViewState.CenterMode?
    private var latestSelection: DashboardCardSelectionState?

    public init(dependencies: RideDashboardCardLifecycleDependencies) {
        self.dependencies = dependencies
    }

    public func receiveContinuity(_ phase: RideDashboardContinuityPhase) {
        guard phase != self.phase else { return }
        self.phase = phase
        applyCardLifecycles(for: phase)
    }

    func setPresentationActive(_ active: Bool) {
        guard isPresentationActive != active else { return }
        isPresentationActive = active
        if !active { pauseAllCards() }
    }

    func synchronize(centerMode: RideDashboardViewState.CenterMode, selection: DashboardCardSelectionState) {
        latestCenterMode = centerMode
        latestSelection = selection
        applyCardLifecycles(for: phase)
    }

    func invalidate() {
        setPresentationActive(false)
        phase = .cold
        latestCenterMode = nil
        latestSelection = nil
    }

    private func applyCardLifecycles(for phase: RideDashboardContinuityPhase) {
        guard isPresentationActive else { return }
        switch phase {
        case .live:
            guard let latestCenterMode, let latestSelection else { return }
            dependencies.range.start()
            dependencies.bikeLock.start()
            synchronizeLiveCardLifecycles(
                centerMode: latestCenterMode,
                selection: latestSelection
            )
        case .recovering:
            pauseRecoverySensitiveCards()
            guard let latestCenterMode, let latestSelection else {
                dependencies.systemHealth.setIsVisible(false)
                return
            }
            dependencies.systemHealth.setIsVisible(
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
            dependencies.charging.start()
        } else {
            dependencies.charging.stop()
        }

        let isCurrentTripVisible = selection.isCurrentTripVisible(in: centerMode)
        dependencies.currentTrip.setIsVisible(
            isCurrentTripVisible && selection.currentTripPage == .current
        )
        dependencies.statistics.setIsVisible(
            isCurrentTripVisible && selection.currentTripPage == .statistics
        )
        dependencies.efficiency.setIsVisible(
            selection.isEfficiencyVisible(in: centerMode),
            page: selection.efficiencyPage
        )
        dependencies.range.setIsVisible(selection.isRangeVisible(in: centerMode))
        dependencies.systemHealth.setIsVisible(selection.isSystemHealthVisible(in: centerMode))
        dependencies.dynamics.setIsVisible(selection.isDynamicsVisible(in: centerMode))
    }

    private func pauseRecoverySensitiveCards() {
        dependencies.currentTrip.setIsVisible(false)
        dependencies.statistics.pause()
        dependencies.efficiency.pause()
        dependencies.range.pause()
        dependencies.dynamics.setIsVisible(false)
    }

    private func pauseAllCards() {
        dependencies.charging.suspend()
        pauseRecoverySensitiveCards()
        dependencies.systemHealth.setIsVisible(false)
        dependencies.bikeLock.suspend()
    }
}
