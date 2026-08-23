public struct ObserveBikeTelemetryUseCase: Sendable {
    private let repository: BikeRepository

    public init(repository: BikeRepository) {
        self.repository = repository
    }

    public func execute() async -> AsyncStream<BikeTelemetry> {
        await repository.observeTelemetry()
    }
}
