public struct ChargingDashboardReadoutViewData: Equatable, Sendable {
    public let title: String
    public let subtitle: String?
    public let accessibilityLabel: String
    public let systemImage: String
    public let emphasis: Emphasis
    public let allowsControl: Bool
    public let showsProgress: Bool

    public init(
        title: String = "CHARGING",
        subtitle: String? = nil,
        accessibilityLabel: String = "Charging unavailable",
        systemImage: String = "bolt.fill",
        emphasis: Emphasis = .charging,
        allowsControl: Bool = true,
        showsProgress: Bool = true
    ) {
        self.title = title
        self.subtitle = subtitle
        self.accessibilityLabel = accessibilityLabel
        self.systemImage = systemImage
        self.emphasis = emphasis
        self.allowsControl = allowsControl
        self.showsProgress = showsProgress
    }

    public enum Emphasis: Equatable, Sendable {
        case charging
        case balancing
        case warning
        case critical
    }
}
