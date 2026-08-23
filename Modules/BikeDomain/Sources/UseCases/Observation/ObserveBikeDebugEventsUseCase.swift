public struct ObserveBikeDebugEventsUseCase: Sendable {
    private let repository: BikeRepository

    public init(repository: BikeRepository) {
        self.repository = repository
    }

    public func execute() async -> AsyncStream<BikeDebugEvent> {
        await repository.observeDebugEvents()
    }
}
