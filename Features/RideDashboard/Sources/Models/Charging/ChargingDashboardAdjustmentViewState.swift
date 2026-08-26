public struct ChargingDashboardAdjustmentViewState: Equatable, Sendable {
    public let isEnabled: Bool
    public let selected: Double
    public let minimum: Double
    public let maximum: Double
    public let step: Double

    public init(
        isEnabled: Bool = true,
        selected: Double,
        minimum: Double,
        maximum: Double,
        step: Double
    ) {
        self.isEnabled = isEnabled
        self.selected = selected
        self.minimum = minimum
        self.maximum = maximum
        self.step = step
    }
}
