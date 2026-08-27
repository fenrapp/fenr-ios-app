public struct LoadRideTripEfficiencyTrendUseCase: Sendable {
    private let repository: any RideTripRepository

    public init(repository: any RideTripRepository) {
        self.repository = repository
    }

    public func execute(vin: String, limit: Int = 10) async -> [RideTrip] {
        let validLimit = max(limit, .zero)
        return Array(
            await repository.loadCompletedTrips(vin: vin)
                .filter(\.isEfficiencyEligibleForHistory)
                .prefix(validLimit)
                .reversed()
        )
    }
}
