public struct StopBatteryHealthMonitoringUseCase: Sendable {
    private let repository: any BikeBatteryHealthRepository

    public init(repository: any BikeBatteryHealthRepository) {
        self.repository = repository
    }

    public func execute() async {
        await repository.stopBatteryHealthMonitoring()
    }
}
