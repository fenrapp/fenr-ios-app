public enum RidingDashboardCard: Int, CaseIterable, Hashable, Sendable {
    case speedometer
    case currentTrip
    case efficiency
    case range
    case dynamics

    var accessibilityLabel: String {
        switch self {
        case .speedometer: "Speedometer"
        case .currentTrip: "Current Trip"
        case .efficiency: "Efficiency"
        case .range: "Range"
        case .dynamics: "Ride Dynamics"
        }
    }
}
