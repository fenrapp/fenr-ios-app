public struct DashboardOdometerViewData: Equatable, Sendable {
    public let valueText: String
    public let accessibilityLabel: String

    public init(
        valueText: String = "--",
        accessibilityLabel: String = "Odometer unavailable"
    ) {
        self.valueText = valueText
        self.accessibilityLabel = accessibilityLabel
    }
}
