enum EfficiencyDashboardPage: Int, CaseIterable, Hashable {
    case live
    case trend

    var accessibilityLabel: String {
        switch self {
        case .live: rideDashboardLocalized(.rideDashboardPageLiveEfficiencyAccessibility)
        case .trend: rideDashboardLocalized(.rideDashboardPageEfficiencyTrendAccessibility)
        }
    }
}
