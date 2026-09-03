public struct BatteryHealthDistributionViewData: Equatable, Sendable {
    public let normalCount: Int
    public let attentionCount: Int
    public let criticalCount: Int

    public var totalCount: Int { normalCount + attentionCount + criticalCount }

    public init(normalCount: Int = 0, attentionCount: Int = 0, criticalCount: Int = 0) {
        self.normalCount = normalCount
        self.attentionCount = attentionCount
        self.criticalCount = criticalCount
    }
}
