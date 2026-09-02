public struct ChargingDashboardReadoutViewData: Equatable, Sendable {
    public let title: String
    public let subtitle: String?
    public let accessibilityLabel: String
    public let systemImage: String
    public let emphasis: Emphasis
    public let allowsControl: Bool
    public let showsProgress: Bool

    public init(
        title: String? = nil,
        subtitle: String? = nil,
        accessibilityLabel: String? = nil,
        systemImage: String = "bolt.fill",
        emphasis: Emphasis = .charging,
        allowsControl: Bool = true,
        showsProgress: Bool = true
    ) {
        self.title = title ?? rideDashboardLocalized(.rideDashboardChargingTitle)
        self.subtitle = subtitle
        self.accessibilityLabel = accessibilityLabel
            ?? rideDashboardLocalized(.rideDashboardChargingUnavailableAccessibility)
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
