public struct ObserveBikeBatteryHealthUseCase: Sendable {
    private let repository: any BikeBatteryHealthRepository

    public init(repository: any BikeBatteryHealthRepository) {
        self.repository = repository
    }

    public func execute() async -> AsyncStream<BikeBatteryHealth> {
        await repository.observeBatteryHealth()
    }
}
