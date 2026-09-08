public struct DashboardDeviceBatteryViewData: Equatable, Sendable {
    public enum Emphasis: Equatable, Sendable {
        case unavailable
        case normal
        case low
        case charging
    }

    public let canChangeDisplayMode: Bool
    public let errorText: String?
    public let percentageText: String
    public let systemImage: String
    public let emphasis: Emphasis
    public let accessibilityLabel: String
    public let isVisible: Bool
    public let showsIcon: Bool
    public let showsPercentage: Bool
    public let displayModeAccessibilityHint: String

    public init(
        canChangeDisplayMode: Bool = true,
        errorText: String? = nil,
        percentageText: String = "--%",
        systemImage: String = "battery.0percent",
        emphasis: Emphasis = .unavailable,
        accessibilityLabel: String? = nil,
        isVisible: Bool = true,
        showsIcon: Bool = true,
        showsPercentage: Bool = true,
        displayModeAccessibilityHint: String? = nil
    ) {
        self.canChangeDisplayMode = canChangeDisplayMode
        self.errorText = errorText
        self.percentageText = percentageText
        self.systemImage = systemImage
        self.emphasis = emphasis
        self.accessibilityLabel = accessibilityLabel
            ?? rideDashboardLocalized(.rideDashboardDeviceBatteryUnavailableAccessibility)
        self.isVisible = isVisible
        self.showsIcon = showsIcon
        self.showsPercentage = showsPercentage
        self.displayModeAccessibilityHint = displayModeAccessibilityHint
            ?? rideDashboardLocalized(.rideDashboardDeviceBatteryDisplayPercentageHint)
    }
}
