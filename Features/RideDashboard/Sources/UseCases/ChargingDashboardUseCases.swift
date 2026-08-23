import BikeDomain
import SettingsDomain

public struct ChargingDashboardUseCases: Sendable {
    public let observeTelemetry: ObserveBikeTelemetryUseCase
    public let observeBatteryHealth: ObserveBikeBatteryHealthUseCase
    public let startBatteryHealthMonitoring: StartBatteryHealthMonitoringUseCase
    public let stopBatteryHealthMonitoring: StopBatteryHealthMonitoringUseCase
    public let observeSettings: ObserveAppSettingsUseCase

    public init(
        observeTelemetry: ObserveBikeTelemetryUseCase,
        observeBatteryHealth: ObserveBikeBatteryHealthUseCase,
        startBatteryHealthMonitoring: StartBatteryHealthMonitoringUseCase,
        stopBatteryHealthMonitoring: StopBatteryHealthMonitoringUseCase,
        observeSettings: ObserveAppSettingsUseCase
    ) {
        self.observeTelemetry = observeTelemetry
        self.observeBatteryHealth = observeBatteryHealth
        self.startBatteryHealthMonitoring = startBatteryHealthMonitoring
        self.stopBatteryHealthMonitoring = stopBatteryHealthMonitoring
        self.observeSettings = observeSettings
    }
}
