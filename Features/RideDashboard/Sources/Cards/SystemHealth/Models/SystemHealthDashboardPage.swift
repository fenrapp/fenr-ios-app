enum SystemHealthDashboardPage: Int, CaseIterable, Hashable, Sendable {
    case health
    case cells
    case thermal

    var accessibilityLabel: String {
        switch self {
        case .health: rideDashboardLocalized(.rideDashboardPageHealthAccessibility)
        case .cells: rideDashboardLocalized(.rideDashboardPageCellsAccessibility)
        case .thermal: rideDashboardLocalized(.rideDashboardPageThermalAccessibility)
        }
    }
}
