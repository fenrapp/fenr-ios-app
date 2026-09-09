public struct BikeSDKTractionControlSnapshot: Equatable, Sendable {
    public let mapIndex: Int
    public let powerRaw: Int
    public let brakingRaw: Int

    public init(mapIndex: Int, powerRaw: Int, brakingRaw: Int) {
        self.mapIndex = mapIndex
        self.powerRaw = powerRaw
        self.brakingRaw = brakingRaw
    }
}
