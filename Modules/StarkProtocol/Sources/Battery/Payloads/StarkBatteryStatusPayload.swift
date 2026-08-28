public struct StarkBatteryStatusPayload: StarkPayload {
    public let positiveFaultBits: UInt32
    public let negativeFaultBits: UInt32

    public init(positiveFaultBits: UInt32, negativeFaultBits: UInt32) {
        self.positiveFaultBits = positiveFaultBits
        self.negativeFaultBits = negativeFaultBits
    }

    public var isFaultActive: Bool {
        positiveFaultBits != 0 || negativeFaultBits != 0
    }
}
