enum SystemHealthDashboardPage: Int, CaseIterable, Hashable, Sendable {
    case health
    case cells
    case thermal

    var accessibilityLabel: String {
        switch self {
        case .health: "Health"
        case .cells: "Cells"
        case .thermal: "Thermal"
        }
    }
}
