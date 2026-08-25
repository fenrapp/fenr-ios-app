public struct BatteryHealthStatusViewData: Equatable, Sendable {
    public let text: String
    public let emphasis: BatteryHealthStatusEmphasis

    public init(text: String, emphasis: BatteryHealthStatusEmphasis) {
        self.text = text
        self.emphasis = emphasis
    }
}
