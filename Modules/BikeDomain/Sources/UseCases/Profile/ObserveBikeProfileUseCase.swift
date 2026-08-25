public struct ObserveBikeProfileUseCase: Sendable {
    private let repository: BikeProfileRepository

    public init(repository: BikeProfileRepository) {
        self.repository = repository
    }

    public func execute() async -> AsyncStream<BikeProfile?> {
        await repository.observeProfile()
    }
}
