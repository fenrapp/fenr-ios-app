enum CurrentTripDashboardPage: Int, CaseIterable, Hashable {
    case current
    case statistics

    var accessibilityLabel: String {
        switch self {
        case .current: rideDashboardLocalized(.rideDashboardPageCurrentTripAccessibility)
        case .statistics: rideDashboardLocalized(.rideDashboardPageRideStatisticsAccessibility)
        }
    }
}
