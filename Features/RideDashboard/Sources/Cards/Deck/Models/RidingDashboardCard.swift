public enum RidingDashboardCard: Int, CaseIterable, Hashable, Sendable {
    case speedometer
    case navigation
    case currentTrip
    case efficiency
    case range
    case systemHealth
    case dynamics

    var accessibilityLabel: String {
        switch self {
        case .speedometer: "Speedometer"
        case .navigation: "Ride Navigation"
        case .currentTrip: "Current Trip"
        case .efficiency: "Efficiency"
        case .range: "Range"
        case .systemHealth: "System Health"
        case .dynamics: "Ride Dynamics"
        }
    }
}
