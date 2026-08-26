public struct StarkLiveEstimationsPayload: StarkPayload {
    public let estimatedRangeRaw: Int
    public let estimatedTimeRaw: Int
    public let nativeMotorPowerRaw: Int

    public init(estimatedRangeRaw: Int, estimatedTimeRaw: Int, nativeMotorPowerRaw: Int) {
        self.estimatedRangeRaw = estimatedRangeRaw
        self.estimatedTimeRaw = estimatedTimeRaw
        self.nativeMotorPowerRaw = nativeMotorPowerRaw
    }
}
