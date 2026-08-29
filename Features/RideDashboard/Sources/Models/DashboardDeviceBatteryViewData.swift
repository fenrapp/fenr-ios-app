import SettingsDomain

public struct DashboardDeviceBatteryViewData: Equatable, Sendable {
    public enum Emphasis: Equatable, Sendable {
        case unavailable
        case normal
        case low
        case charging
    }

    public let percentageText: String
    public let systemImage: String
    public let emphasis: Emphasis
    public let accessibilityLabel: String
    public let displayMode: DashboardDeviceBatteryDisplayMode

    public init(
        percentageText: String = "--%",
        systemImage: String = "battery.0percent",
        emphasis: Emphasis = .unavailable,
        accessibilityLabel: String = "iPhone battery unavailable",
        displayMode: DashboardDeviceBatteryDisplayMode = .icon
    ) {
        self.percentageText = percentageText
        self.systemImage = systemImage
        self.emphasis = emphasis
        self.accessibilityLabel = accessibilityLabel
        self.displayMode = displayMode
    }
}
