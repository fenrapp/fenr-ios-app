public struct ClearBikeProfileUseCase: Sendable {
    private let repository: BikeProfileRepository

    public init(repository: BikeProfileRepository) {
        self.repository = repository
    }

    public func execute() async {
        await repository.clearProfile()
    }
}
