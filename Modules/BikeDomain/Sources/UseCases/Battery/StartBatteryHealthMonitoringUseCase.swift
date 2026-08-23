public struct StartBatteryHealthMonitoringUseCase: Sendable {
    private let repository: any BikeBatteryHealthRepository

    public init(repository: any BikeBatteryHealthRepository) {
        self.repository = repository
    }

    public func execute() async throws {
        try await repository.startBatteryHealthMonitoring()
    }
}
