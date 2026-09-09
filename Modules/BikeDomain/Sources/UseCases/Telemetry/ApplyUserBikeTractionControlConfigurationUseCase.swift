public struct ApplyUserBikeTractionControlConfigurationUseCase: Sendable {
    private let repository: any BikeControlRepository

    public init(repository: any BikeControlRepository) { self.repository = repository }

    public func execute(
        mapIndex: Int, powerTractionPercent: Double, brakingTractionPercent: Double,
        expected: BikeTractionControlSnapshot? = nil
    ) async throws -> BikeTractionControlSnapshot {
        try await repository.applyUserTractionControlConfiguration(
            mapIndex: mapIndex, powerTractionPercent: powerTractionPercent,
            brakingTractionPercent: brakingTractionPercent, expected: expected
        )
    }
}
