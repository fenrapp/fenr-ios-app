public struct BatteryHealthThermalViewData: Equatable, Sendable {
    public let metrics: [BatteryHealthMetricViewData]
    public let sensors: [BatteryTemperatureViewData]
    public let valueRangeCelsius: ClosedRange<Double>?
    public let averageCelsius: Double?
    public let displayDomainCelsius: ClosedRange<Double>?
    public let emphasis: BatteryHealthStatusEmphasis

    public init(
        metrics: [BatteryHealthMetricViewData] = [],
        sensors: [BatteryTemperatureViewData] = [],
        valueRangeCelsius: ClosedRange<Double>? = nil,
        averageCelsius: Double? = nil,
        displayDomainCelsius: ClosedRange<Double>? = nil,
        emphasis: BatteryHealthStatusEmphasis = .neutral
    ) {
        self.metrics = metrics
        self.sensors = sensors
        self.valueRangeCelsius = valueRangeCelsius
        self.averageCelsius = averageCelsius
        self.displayDomainCelsius = displayDomainCelsius
        self.emphasis = emphasis
    }
}
