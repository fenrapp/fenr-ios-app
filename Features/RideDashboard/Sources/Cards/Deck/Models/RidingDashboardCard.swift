public enum RidingDashboardCard: Int, CaseIterable, Hashable, Sendable {
    case speedometer
    case bikeLock
    case navigation
    case currentTrip
    case efficiency
    case range
    case systemHealth
    case dynamics
    case settings

    var accessibilityLabel: String {
        switch self {
        case .speedometer: rideDashboardLocalized(.rideDashboardCardSpeedometerAccessibility)
        case .bikeLock: rideDashboardLocalized(.rideDashboardCardBikeLockAccessibility)
        case .navigation: rideDashboardLocalized(.rideDashboardCardNavigationAccessibility)
        case .currentTrip: rideDashboardLocalized(.rideDashboardCardCurrentTripAccessibility)
        case .efficiency: rideDashboardLocalized(.rideDashboardCardEfficiencyAccessibility)
        case .range: rideDashboardLocalized(.rideDashboardCardRangeAccessibility)
        case .systemHealth: rideDashboardLocalized(.rideDashboardCardSystemHealthAccessibility)
        case .settings: rideDashboardLocalized(.rideDashboardHeaderSettings)
        case .dynamics: rideDashboardLocalized(.rideDashboardCardDynamicsAccessibility)
        }
    }
}
