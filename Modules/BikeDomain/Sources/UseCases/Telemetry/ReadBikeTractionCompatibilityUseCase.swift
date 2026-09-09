public struct ReadBikeTractionCompatibilityUseCase: Sendable {
    private let repository: any BikeControlRepository

    public init(repository: any BikeControlRepository) { self.repository = repository }

    public func execute() async throws -> BikeTractionControlFirmwareCompatibility {
        try await repository.readTractionControlFirmwareCompatibility()
    }
}
