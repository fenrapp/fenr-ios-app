public struct DashboardSpeedometerViewData: Equatable, Sendable {
    public let valueText: String
    public let unit: String
    public let progress: Double
    public let accessibilityLabel: String

    public init(
        valueText: String = "0",
        unit: String = "km/h",
        progress: Double = .zero,
        accessibilityLabel: String = "Speed 0 km/h"
    ) {
        self.valueText = valueText
        self.unit = unit
        self.progress = progress
        self.accessibilityLabel = accessibilityLabel
    }
}
