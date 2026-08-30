public struct RefreshBikePowerModeConfigurationUseCase: Sendable {
    private let repository: any BikeControlRepository

    public init(repository: any BikeControlRepository) {
        self.repository = repository
    }

    public func execute(mapIndex: Int) async throws {
        try await repository.refreshPowerModeConfiguration(mapIndex: mapIndex)
    }
}
