import BikeDomain
import SettingsDomain

public struct BatteryHealthUseCases: Sendable {
    public let startMonitoring: StartBatteryHealthMonitoringUseCase
    public let stopMonitoring: StopBatteryHealthMonitoringUseCase
    public let observeHealth: ObserveBikeBatteryHealthUseCase
    public let observeCaptures: ObserveBatteryDatasetCapturesUseCase
    public let observeSettings: ObserveAppSettingsUseCase

    public init(
        startMonitoring: StartBatteryHealthMonitoringUseCase,
        stopMonitoring: StopBatteryHealthMonitoringUseCase,
        observeHealth: ObserveBikeBatteryHealthUseCase,
        observeCaptures: ObserveBatteryDatasetCapturesUseCase,
        observeSettings: ObserveAppSettingsUseCase
    ) {
        self.startMonitoring = startMonitoring
        self.stopMonitoring = stopMonitoring
        self.observeHealth = observeHealth
        self.observeCaptures = observeCaptures
        self.observeSettings = observeSettings
    }
}
