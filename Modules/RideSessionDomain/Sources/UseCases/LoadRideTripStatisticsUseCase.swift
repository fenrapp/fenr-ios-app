public struct LoadRideTripStatisticsUseCase: Sendable {
    private let repository: any RideTripRepository
    private let aggregator: RideTripStatisticsAggregator

    public init(
        repository: any RideTripRepository,
        aggregator: RideTripStatisticsAggregator
    ) {
        self.repository = repository
        self.aggregator = aggregator
    }

    public func execute(vin: String) async -> RideTripStatistics {
        aggregator.aggregate(await repository.loadCompletedTrips(vin: vin))
    }
}
