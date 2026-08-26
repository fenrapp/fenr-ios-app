public struct ObserveBikePowerTelemetryUseCase: Sendable {
    private let repository: BikeRepository

    public init(repository: BikeRepository) {
        self.repository = repository
    }

    public func execute() async -> AsyncStream<BikePowerTelemetry> {
        await observeBikeTelemetryProjection(repository: repository, transform: \.powerTelemetry)
    }
}
