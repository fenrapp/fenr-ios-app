public struct StarkBatteryBalancingPayload: StarkPayload {
    public let activeCellIndexes: Set<Int>

    public init(activeCellIndexes: Set<Int>) {
        self.activeCellIndexes = activeCellIndexes
    }
}
