public struct DashboardGearViewData: Equatable, Sendable {
    public enum Display: Equatable, Sendable {
        case text(String)
        case crawlForward
        case crawlReverse
    }

    public let display: Display
    public let isActive: Bool
    public let showsAdvancedCurve: Bool
    public let accessibilityLabel: String

    public init(
        display: Display = .text("--"),
        isActive: Bool = false,
        showsAdvancedCurve: Bool = false,
        accessibilityLabel: String? = nil
    ) {
        self.display = display
        self.isActive = isActive
        self.showsAdvancedCurve = showsAdvancedCurve
        self.accessibilityLabel = accessibilityLabel
            ?? rideDashboardLocalized(.rideDashboardGearUnavailableAccessibility)
    }
}
