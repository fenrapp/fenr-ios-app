public struct ObserveBatteryDatasetCapturesUseCase: Sendable {
    private let repository: any BikeBatteryHealthRepository

    public init(repository: any BikeBatteryHealthRepository) {
        self.repository = repository
    }

    public func execute() async -> AsyncStream<BatteryDatasetCapture> {
        await repository.observeBatteryDatasetCaptures()
    }
}
