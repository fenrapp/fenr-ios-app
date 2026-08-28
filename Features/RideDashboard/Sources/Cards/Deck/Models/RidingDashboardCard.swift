public enum RidingDashboardCard: Int, CaseIterable, Hashable, Sendable {
    case speedometer
    case currentTrip
    case efficiency
    case range
    case systemHealth
    case dynamics

    var accessibilityLabel: String {
        switch self {
        case .speedometer: "Speedometer"
        case .currentTrip: "Current Trip"
        case .efficiency: "Efficiency"
        case .range: "Range"
        case .systemHealth: "System Health"
        case .dynamics: "Ride Dynamics"
        }
    }
}
