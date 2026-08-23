public struct ConnectToBikeUseCase: Sendable {
    private let repository: BikeRepository

    public init(repository: BikeRepository) {
        self.repository = repository
    }

    public func execute(vin: String) async throws {
        try await repository.connect(vin: vin)
    }
}
