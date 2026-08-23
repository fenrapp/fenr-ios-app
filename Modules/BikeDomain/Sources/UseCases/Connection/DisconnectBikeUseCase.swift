public struct DisconnectBikeUseCase: Sendable {
    private let repository: BikeRepository

    public init(repository: BikeRepository) {
        self.repository = repository
    }

    public func execute() async throws {
        try await repository.disconnect()
    }
}
