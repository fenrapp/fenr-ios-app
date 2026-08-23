public struct StarkLiveTotalsPayload: StarkPayload {
    public let firstRawCounter: UInt32
    public let secondRawCounter: UInt32
    public let thirdRawCounter: UInt32
    public let fourthRawCounter: UInt32

    public init(
        firstRawCounter: UInt32,
        secondRawCounter: UInt32,
        thirdRawCounter: UInt32,
        fourthRawCounter: UInt32
    ) {
        self.firstRawCounter = firstRawCounter
        self.secondRawCounter = secondRawCounter
        self.thirdRawCounter = thirdRawCounter
        self.fourthRawCounter = fourthRawCounter
    }

    public var odometerCentiKilometers: UInt32 {
        firstRawCounter
    }

    public var odometerKilometers: Double {
        Double(odometerCentiKilometers) / 100.0
    }
}
