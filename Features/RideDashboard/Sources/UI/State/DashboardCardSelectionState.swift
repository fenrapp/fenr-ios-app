struct DashboardCardSelectionState: Equatable {
    var ridingCard = RidingDashboardCard.speedometer
    var currentTripPage = CurrentTripDashboardPage.current
    var efficiencyPage = EfficiencyDashboardPage.live
    var rangePage = RangeDashboardPage.range
    var systemHealthPage = SystemHealthDashboardPage.health
    var dynamicsPage = RideDynamicsDashboardPage.lean

    init(
        ridingCard: RidingDashboardCard = .speedometer,
        currentTripPage: CurrentTripDashboardPage = .current,
        efficiencyPage: EfficiencyDashboardPage = .live,
        rangePage: RangeDashboardPage = .range,
        systemHealthPage: SystemHealthDashboardPage = .health,
        dynamicsPage: RideDynamicsDashboardPage = .lean,
        layout: DashboardCardLayout? = nil
    ) {
        self.ridingCard = ridingCard
        self.currentTripPage = currentTripPage
        self.efficiencyPage = efficiencyPage
        self.rangePage = rangePage
        self.systemHealthPage = systemHealthPage
        self.dynamicsPage = dynamicsPage
        if let layout {
            apply(layout: layout)
        }
    }

    func isSpeedometerVisible(in centerMode: RideDashboardViewState.CenterMode) -> Bool {
        centerMode == .riding && ridingCard == .speedometer
    }

    func showsCompactSpeed(_ isEnabled: Bool) -> Bool {
        ridingCard != .speedometer && isEnabled
    }

    func isCurrentTripVisible(in centerMode: RideDashboardViewState.CenterMode) -> Bool {
        centerMode == .riding && ridingCard == .currentTrip
    }

    func isEfficiencyVisible(in centerMode: RideDashboardViewState.CenterMode) -> Bool {
        centerMode == .riding && ridingCard == .efficiency
    }

    func isRangeVisible(in centerMode: RideDashboardViewState.CenterMode) -> Bool {
        centerMode == .riding && ridingCard == .range
    }

    func isDynamicsVisible(in centerMode: RideDashboardViewState.CenterMode) -> Bool {
        centerMode == .riding && ridingCard == .dynamics
    }

    func isSystemHealthVisible(in centerMode: RideDashboardViewState.CenterMode) -> Bool {
        centerMode == .riding && ridingCard == .systemHealth
    }

    func needsHiddenPageReset(
        in centerMode: RideDashboardViewState.CenterMode,
        layout: DashboardCardLayout = .init()
    ) -> Bool {
        (!isCurrentTripVisible(in: centerMode) && currentTripPage != layout.currentTripPages[0])
            || (!isEfficiencyVisible(in: centerMode) && efficiencyPage != layout.efficiencyPages[0])
            || (!isRangeVisible(in: centerMode) && rangePage != layout.rangePages[0])
            || (!isSystemHealthVisible(in: centerMode) && systemHealthPage != layout.systemHealthPages[0])
            || (!isDynamicsVisible(in: centerMode) && dynamicsPage != layout.dynamicsPages[0])
    }

    mutating func selectSpeedometer() {
        ridingCard = .speedometer
    }

    mutating func resetHiddenPages(
        in centerMode: RideDashboardViewState.CenterMode,
        layout: DashboardCardLayout = .init()
    ) {
        if !isCurrentTripVisible(in: centerMode) {
            currentTripPage = layout.currentTripPages[0]
        }
        if !isEfficiencyVisible(in: centerMode) {
            efficiencyPage = layout.efficiencyPages[0]
        }
        if !isRangeVisible(in: centerMode) {
            rangePage = layout.rangePages[0]
        }
        if !isSystemHealthVisible(in: centerMode) {
            systemHealthPage = layout.systemHealthPages[0]
        }
        if !isDynamicsVisible(in: centerMode) {
            dynamicsPage = layout.dynamicsPages[0]
        }
    }

    mutating func apply(layout: DashboardCardLayout) {
        if !layout.ridingCards.contains(ridingCard) {
            ridingCard = .speedometer
        }
        currentTripPage = layout.currentTripPages[0]
        efficiencyPage = layout.efficiencyPages[0]
        rangePage = layout.rangePages[0]
        systemHealthPage = layout.systemHealthPages[0]
        dynamicsPage = layout.dynamicsPages[0]
    }
}
