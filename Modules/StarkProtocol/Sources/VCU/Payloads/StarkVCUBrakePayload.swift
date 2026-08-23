public struct StarkVCUBrakePayload: StarkPayload {
    public let primaryBrakeSignal: UInt16
    public let secondaryBrakeSignal: UInt16

    public init(primaryBrakeSignal: UInt16, secondaryBrakeSignal: UInt16) {
        self.primaryBrakeSignal = primaryBrakeSignal
        self.secondaryBrakeSignal = secondaryBrakeSignal
    }

    public var isBrakeActive: Bool {
        primaryBrakeSignal != 0 || secondaryBrakeSignal != 0
    }
}
