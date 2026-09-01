public struct SetBikePowerModeConfigurationUseCase: Sendable {
    private let repository: any BikeControlRepository

    public init(repository: any BikeControlRepository) {
        self.repository = repository
    }

    public func execute(
        mapIndex: Int,
        horsepower: Int,
        regenerativeBrakingPercent: Int
    ) async throws {
        try await repository.setPowerModeConfiguration(
            mapIndex: mapIndex,
            horsepower: horsepower,
            regenerativeBrakingPercent: regenerativeBrakingPercent
        )
    }
}
