public struct ChargingDashboardReadoutViewData: Equatable, Sendable {
    public let title: String
    public let usesEstimatedTimeStyle: Bool
    public let accessibilityLabel: String

    public init(
        title: String = "CHARGING",
        usesEstimatedTimeStyle: Bool = false,
        accessibilityLabel: String = "Charging unavailable"
    ) {
        self.title = title
        self.usesEstimatedTimeStyle = usesEstimatedTimeStyle
        self.accessibilityLabel = accessibilityLabel
    }
}
