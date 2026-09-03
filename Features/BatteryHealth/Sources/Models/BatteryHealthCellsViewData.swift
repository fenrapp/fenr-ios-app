public struct BatteryHealthCellsViewData: Equatable, Sendable {
    public let metrics: [BatteryHealthMetricViewData]
    public let distribution: BatteryHealthDistributionViewData
    public let cells: [BatteryCellViewData]
    public let balancingCount: Int

    public init(
        metrics: [BatteryHealthMetricViewData] = [],
        distribution: BatteryHealthDistributionViewData = .init(),
        cells: [BatteryCellViewData] = [],
        balancingCount: Int = 0
    ) {
        self.metrics = metrics
        self.distribution = distribution
        self.cells = cells
        self.balancingCount = balancingCount
    }
}
