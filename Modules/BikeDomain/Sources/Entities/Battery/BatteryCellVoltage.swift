public struct BatteryCellVoltage: Equatable, Sendable, Identifiable {
    public let position: Int
    public let volts: Double

    public var id: Int { position }

    public init(position: Int, volts: Double) {
        self.position = position
        self.volts = volts
    }
}
