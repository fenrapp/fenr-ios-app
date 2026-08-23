public struct BatteryTemperature: Equatable, Sendable, Identifiable {
    public let position: Int
    public let celsius: Double

    public var id: Int { position }

    public init(position: Int, celsius: Double) {
        self.position = position
        self.celsius = celsius
    }
}
