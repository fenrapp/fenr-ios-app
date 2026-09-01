public struct RefreshBikePowerModesUseCase: Sendable {
    private let repository: any BikeControlRepository

    public init(repository: any BikeControlRepository) {
        self.repository = repository
    }

    public func execute() async throws {
        try await repository.refreshPowerModeConfigurations()
    }
}
