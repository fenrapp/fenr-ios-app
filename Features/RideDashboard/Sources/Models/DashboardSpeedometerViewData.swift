public struct DashboardSpeedometerViewData: Equatable, Sendable {
    public let valueText: String
    public let unit: String
    public let progress: Double
    public let sourceIndicator: DashboardSpeedSourceIndicatorViewData?
    public let accessibilityLabel: String

    public init(
        valueText: String = "0",
        unit: String = "km/h",
        progress: Double = .zero,
        sourceIndicator: DashboardSpeedSourceIndicatorViewData? = nil,
        accessibilityLabel: String? = nil
    ) {
        self.valueText = valueText
        self.unit = unit
        self.progress = progress
        self.sourceIndicator = sourceIndicator
        self.accessibilityLabel = accessibilityLabel
            ?? rideDashboardLocalized(.rideDashboardSpeedDefaultAccessibility)
    }
}
