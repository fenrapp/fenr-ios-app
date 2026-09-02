public struct DashboardOdometerViewData: Equatable, Sendable {
    public let valueText: String
    public let accessibilityLabel: String

    public init(
        valueText: String = "--",
        accessibilityLabel: String? = nil
    ) {
        self.valueText = valueText
        self.accessibilityLabel = accessibilityLabel
            ?? rideDashboardLocalized(.rideDashboardOdometerUnavailableAccessibility)
    }
}
