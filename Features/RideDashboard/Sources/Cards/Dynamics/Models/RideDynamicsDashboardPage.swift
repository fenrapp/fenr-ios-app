public enum RideDynamicsDashboardPage: Int, CaseIterable, Hashable, Sendable {
    case lean
    case pitch
    case course
    case altitude

    public static let allCases: [Self] = [.lean, .pitch, .altitude, .course]

    var accessibilityLabel: String {
        switch self {
        case .lean: rideDashboardLocalized(.rideDashboardPageLeanAccessibility)
        case .pitch: rideDashboardLocalized(.rideDashboardPagePitchAccessibility)
        case .altitude: rideDashboardLocalized(.rideDashboardAltitudeTitle)
        case .course: rideDashboardLocalized(.rideDashboardPageCourseAccessibility)
        }
    }
}
