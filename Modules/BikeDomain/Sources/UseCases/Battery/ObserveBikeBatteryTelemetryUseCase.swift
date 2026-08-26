public struct ObserveBikeBatteryTelemetryUseCase: Sendable {
    private let repository: BikeRepository

    public init(repository: BikeRepository) {
        self.repository = repository
    }

    public func execute() async -> AsyncStream<BikeBatteryTelemetry> {
        await observeBikeTelemetryProjection(repository: repository, transform: \.batteryTelemetry)
    }
}
