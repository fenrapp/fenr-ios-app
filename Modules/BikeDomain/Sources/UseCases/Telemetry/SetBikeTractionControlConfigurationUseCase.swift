public struct SetBikeTractionControlConfigurationUseCase: Sendable {
    private let repository: any BikeControlRepository

    public init(repository: any BikeControlRepository) {
        self.repository = repository
    }

    public func execute(
        mapIndex: Int,
        powerTractionPercent: Double,
        brakingTractionPercent: Double
    ) async throws {
        try await repository.setTractionControlConfiguration(
            mapIndex: mapIndex,
            powerTractionPercent: powerTractionPercent,
            brakingTractionPercent: brakingTractionPercent
        )
    }
}
