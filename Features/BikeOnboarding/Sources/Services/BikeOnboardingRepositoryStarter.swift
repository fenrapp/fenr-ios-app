import BikeDomain

@MainActor
public final class BikeOnboardingRepositoryStarter {
    private let startRepository: StartBikeRepositoryUseCase
    private var startTask: Task<Void, Never>?

    public init(startRepository: StartBikeRepositoryUseCase) {
        self.startRepository = startRepository
    }

    deinit {
        startTask?.cancel()
    }

    func start() -> Task<Void, Never> {
        if let startTask { return startTask }
        let startRepository = startRepository
        let task = Task { await startRepository.execute() }
        startTask = task
        return task
    }
}
