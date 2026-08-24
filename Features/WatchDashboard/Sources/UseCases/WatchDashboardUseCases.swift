import BikeDomain
import SettingsDomain

public struct WatchDashboardUseCases: Sendable {
    let observeTelemetry: ObserveBikeTelemetryUseCase
    let observeConnection: ObserveBikeConnectionUseCase
    let observeDebugEvents: ObserveBikeDebugEventsUseCase
    let observeBatteryHealth: ObserveBikeBatteryHealthUseCase
    let startBatteryHealthMonitoring: StartBatteryHealthMonitoringUseCase
    let stopBatteryHealthMonitoring: StopBatteryHealthMonitoringUseCase
    let observeSettings: ObserveAppSettingsUseCase

    public init(
        repository: any BikeRepository,
        batteryHealthRepository: any BikeBatteryHealthRepository,
        settingsRepository: any AppSettingsRepository
    ) {
        observeTelemetry = ObserveBikeTelemetryUseCase(repository: repository)
        observeConnection = ObserveBikeConnectionUseCase(repository: repository)
        observeDebugEvents = ObserveBikeDebugEventsUseCase(repository: repository)
        observeBatteryHealth = ObserveBikeBatteryHealthUseCase(repository: batteryHealthRepository)
        startBatteryHealthMonitoring = StartBatteryHealthMonitoringUseCase(repository: batteryHealthRepository)
        stopBatteryHealthMonitoring = StopBatteryHealthMonitoringUseCase(repository: batteryHealthRepository)
        observeSettings = ObserveAppSettingsUseCase(repository: settingsRepository)
    }
}
