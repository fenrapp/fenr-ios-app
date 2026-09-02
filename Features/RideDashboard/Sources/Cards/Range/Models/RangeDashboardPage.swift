public enum RangeDashboardPage: Int, CaseIterable, Hashable, Sendable {
    case range
    case battery

    var accessibilityLabel: String {
        switch self {
        case .range: rideDashboardLocalized(.rideDashboardCardRangeAccessibility)
        case .battery: rideDashboardLocalized(.rideDashboardPageBatteryTripAccessibility)
        }
    }
}
