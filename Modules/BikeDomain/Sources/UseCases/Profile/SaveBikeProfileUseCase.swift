public struct SaveBikeProfileUseCase: Sendable {
    private let repository: BikeProfileRepository

    public init(repository: BikeProfileRepository) {
        self.repository = repository
    }

    public func execute(_ profile: BikeProfile) async {
        await repository.saveProfile(profile)
    }
}
