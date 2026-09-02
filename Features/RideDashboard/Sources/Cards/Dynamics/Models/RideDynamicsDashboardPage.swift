public enum RideDynamicsDashboardPage: Int, CaseIterable, Hashable, Sendable {
    case lean
    case pitch
    case course

    var accessibilityLabel: String {
        switch self {
        case .lean: rideDashboardLocalized(.rideDashboardPageLeanAccessibility)
        case .pitch: rideDashboardLocalized(.rideDashboardPagePitchAccessibility)
        case .course: rideDashboardLocalized(.rideDashboardPageCourseAccessibility)
        }
    }
}
