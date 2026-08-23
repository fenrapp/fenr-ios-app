import BikeDomain

public struct WatchDashboardUseCases: Sendable {
    let observeTelemetry: ObserveBikeTelemetryUseCase
    let observeConnection: ObserveBikeConnectionUseCase
    let observeBatteryHealth: ObserveBikeBatteryHealthUseCase
    let startBatteryHealthMonitoring: StartBatteryHealthMonitoringUseCase
    let stopBatteryHealthMonitoring: StopBatteryHealthMonitoringUseCase

    public init(
        repository: any BikeRepository,
        batteryHealthRepository: any BikeBatteryHealthRepository
    ) {
        observeTelemetry = ObserveBikeTelemetryUseCase(repository: repository)
        observeConnection = ObserveBikeConnectionUseCase(repository: repository)
        observeBatteryHealth = ObserveBikeBatteryHealthUseCase(repository: batteryHealthRepository)
        startBatteryHealthMonitoring = StartBatteryHealthMonitoringUseCase(repository: batteryHealthRepository)
        stopBatteryHealthMonitoring = StopBatteryHealthMonitoringUseCase(repository: batteryHealthRepository)
    }
}
