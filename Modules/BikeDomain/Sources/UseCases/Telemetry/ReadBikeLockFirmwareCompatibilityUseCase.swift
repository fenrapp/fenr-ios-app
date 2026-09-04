public struct ReadBikeLockFirmwareCompatibilityUseCase: Sendable {
    private let repository: any BikeControlRepository

    public init(repository: any BikeControlRepository) {
        self.repository = repository
    }

    public func execute() async throws -> BikeLockFirmwareCompatibility {
        try await repository.readBikeLockFirmwareCompatibility()
    }
}
