public struct BatteryTemperatureViewData: Equatable, Identifiable, Sendable {
    public let position: Int
    public let value: String
    public let emphasis: BatteryHealthStatusEmphasis

    public var id: Int { position }

    public init(
        position: Int,
        value: String,
        emphasis: BatteryHealthStatusEmphasis = .neutral
    ) {
        self.position = position
        self.value = value
        self.emphasis = emphasis
    }
}
