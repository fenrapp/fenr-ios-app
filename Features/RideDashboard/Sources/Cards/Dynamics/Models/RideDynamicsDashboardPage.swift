public enum RideDynamicsDashboardPage: Int, CaseIterable, Hashable, Sendable {
    case lean
    case pitch
    case course

    var accessibilityLabel: String {
        switch self {
        case .lean: "Lean"
        case .pitch: "Pitch"
        case .course: "Course"
        }
    }
}
