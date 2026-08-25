public struct DashboardSpeedometerViewData: Equatable, Sendable {
    public let value: Double
    public let unit: String
    public let progress: Double
    public let emphasis: DashboardGaugeEmphasis
    public let accessibilityLabel: String

    public init(
        value: Double = .zero,
        unit: String = "km/h",
        progress: Double = .zero,
        emphasis: DashboardGaugeEmphasis = .informational,
        accessibilityLabel: String = "Speed 0 km/h"
    ) {
        self.value = value
        self.unit = unit
        self.progress = progress
        self.emphasis = emphasis
        self.accessibilityLabel = accessibilityLabel
    }
}
