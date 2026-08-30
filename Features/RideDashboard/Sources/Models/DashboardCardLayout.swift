struct DashboardCardLayout: Equatable, Sendable {
    let ridingCards: [RidingDashboardCard]
    let currentTripPages: [CurrentTripDashboardPage]
    let efficiencyPages: [EfficiencyDashboardPage]
    let rangePages: [RangeDashboardPage]
    let systemHealthPages: [SystemHealthDashboardPage]
    let dynamicsPages: [RideDynamicsDashboardPage]

    init(
        ridingCards: [RidingDashboardCard] = RidingDashboardCard.allCases,
        currentTripPages: [CurrentTripDashboardPage] = CurrentTripDashboardPage.allCases,
        efficiencyPages: [EfficiencyDashboardPage] = EfficiencyDashboardPage.allCases,
        rangePages: [RangeDashboardPage] = RangeDashboardPage.allCases,
        systemHealthPages: [SystemHealthDashboardPage] = SystemHealthDashboardPage.allCases,
        dynamicsPages: [RideDynamicsDashboardPage] = RideDynamicsDashboardPage.allCases
    ) {
        self.ridingCards = [.speedometer] + ridingCards.filter { $0 != .speedometer }
        self.currentTripPages = currentTripPages.isEmpty ? [.current] : currentTripPages
        self.efficiencyPages = efficiencyPages.isEmpty ? [.live] : efficiencyPages
        self.rangePages = rangePages.isEmpty ? [.range] : rangePages
        self.systemHealthPages = systemHealthPages.isEmpty ? [.health] : systemHealthPages
        self.dynamicsPages = dynamicsPages.isEmpty ? [.lean] : dynamicsPages
    }
}
