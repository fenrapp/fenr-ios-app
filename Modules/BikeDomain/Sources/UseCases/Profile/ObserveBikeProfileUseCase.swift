public struct ObserveBikeProfileUseCase: Sendable {
    private let repository: BikeProfileRepository

    public init(repository: BikeProfileRepository) {
        self.repository = repository
    }

    public func execute() async -> AsyncStream<BikeProfileState> {
        await repository.observeProfile()
    }
}
