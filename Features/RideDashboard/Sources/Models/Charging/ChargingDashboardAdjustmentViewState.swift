public struct ChargingDashboardAdjustmentViewState: Equatable, Sendable {
    public let selected: Double
    public let minimum: Double
    public let maximum: Double
    public let step: Double

    public init(selected: Double, minimum: Double, maximum: Double, step: Double) {
        self.selected = selected
        self.minimum = minimum
        self.maximum = maximum
        self.step = step
    }
}
