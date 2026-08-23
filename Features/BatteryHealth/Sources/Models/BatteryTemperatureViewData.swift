public struct BatteryTemperatureViewData: Equatable, Identifiable, Sendable {
    public let position: Int
    public let value: String

    public var id: Int { position }

    public init(position: Int, value: String) {
        self.position = position
        self.value = value
    }
}
