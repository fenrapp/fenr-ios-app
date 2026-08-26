public enum RidingDashboardCard: Int, CaseIterable, Hashable, Sendable {
    case speedometer
    case currentTrip

    var accessibilityLabel: String {
        switch self {
        case .speedometer: "Speedometer"
        case .currentTrip: "Current Trip"
        }
    }
}
