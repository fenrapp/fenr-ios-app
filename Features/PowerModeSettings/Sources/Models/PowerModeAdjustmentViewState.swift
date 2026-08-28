public struct PowerModeAdjustmentViewState: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let value: Double?
    public let valueText: String
    public let unit: String
    public let minimum: Double
    public let maximum: Double
    public let step: Double
    public let isEnabled: Bool

    public init(
        id: String,
        title: String,
        value: Double?,
        valueText: String,
        unit: String,
        minimum: Double,
        maximum: Double,
        step: Double,
        isEnabled: Bool
    ) {
        self.id = id
        self.title = title
        self.value = value
        self.valueText = valueText
        self.unit = unit
        self.minimum = minimum
        self.maximum = maximum
        self.step = step
        self.isEnabled = isEnabled
    }
}
