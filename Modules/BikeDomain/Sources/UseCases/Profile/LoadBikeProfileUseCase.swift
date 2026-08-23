public struct LoadBikeProfileUseCase: Sendable {
    private let repository: BikeProfileRepository

    public init(repository: BikeProfileRepository) {
        self.repository = repository
    }

    public func execute() async -> BikeProfile? {
        await repository.loadProfile()
    }
}
