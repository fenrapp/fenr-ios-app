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

    public func execute(vin: String) async throws -> RideTripStatistics {
        aggregator.aggregate(try await repository.loadCompletedTrips(vin: vin))
    }
}
