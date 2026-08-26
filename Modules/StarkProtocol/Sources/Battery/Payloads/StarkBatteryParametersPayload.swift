public struct StarkBatteryParametersPayload: StarkPayload {
    public let seriesCount: Int
    public let parallelCount: Int
    public let capacityRaw: Int

    public init(seriesCount: Int, parallelCount: Int, capacityRaw: Int) {
        self.seriesCount = seriesCount
        self.parallelCount = parallelCount
        self.capacityRaw = capacityRaw
    }
}
