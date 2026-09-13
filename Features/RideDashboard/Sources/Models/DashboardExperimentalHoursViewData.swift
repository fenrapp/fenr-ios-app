public struct DashboardExperimentalHoursViewData: Equatable, Sendable {
    public let valueText: String
    public let accessibilityLabel: String
    public let rawCounterText: String

    public init(valueText: String, accessibilityLabel: String, rawCounterText: String) {
        self.valueText = valueText
        self.accessibilityLabel = accessibilityLabel
        self.rawCounterText = rawCounterText
    }
}
