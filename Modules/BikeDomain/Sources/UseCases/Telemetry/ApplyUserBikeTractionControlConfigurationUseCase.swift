public struct ApplyUserBikeTractionControlConfigurationUseCase: Sendable {
    private let repository: any BikeControlRepository

    public init(repository: any BikeControlRepository) { self.repository = repository }

    public func execute(
        mapIndex: Int, powerTractionPercent: Double, brakingTractionPercent: Double
    ) async throws -> BikeTractionControlSnapshot {
        try await repository.applyUserTractionControlConfiguration(
            mapIndex: mapIndex, powerTractionPercent: powerTractionPercent,
            brakingTractionPercent: brakingTractionPercent
        )
    }
}
