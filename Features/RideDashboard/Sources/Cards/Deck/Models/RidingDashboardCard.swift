public enum RidingDashboardCard: Int, CaseIterable, Hashable, Sendable {
    case speedometer
    case currentTrip
    case efficiency

    var accessibilityLabel: String {
        switch self {
        case .speedometer: "Speedometer"
        case .currentTrip: "Current Trip"
        case .efficiency: "Efficiency"
        }
    }
}
