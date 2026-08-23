public struct StartBikeRepositoryUseCase: Sendable {
    private let repository: BikeRepository

    public init(repository: BikeRepository) {
        self.repository = repository
    }

    public func execute() async {
        await repository.start()
    }
}
