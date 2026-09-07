public struct LoadRideTripEfficiencyTrendUseCase: Sendable {
    private let repository: any RideTripRepository

    public init(repository: any RideTripRepository) {
        self.repository = repository
    }

    public func execute(vin: String, limit: Int = 10) async throws -> [RideTrip] {
        let validLimit = max(limit, .zero)
        return Array(
            try await repository.loadCompletedTrips(vin: vin)
                .filter(\.isEfficiencyEligibleForHistory)
                .prefix(validLimit)
                .reversed()
        )
    }
}
