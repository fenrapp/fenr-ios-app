public struct ObserveBikeConnectionUseCase: Sendable {
    private let repository: BikeRepository

    public init(repository: BikeRepository) {
        self.repository = repository
    }

    public func execute() async -> AsyncStream<BikeConnection> {
        await repository.observeConnection()
    }
}
