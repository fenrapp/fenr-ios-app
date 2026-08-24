import BikeDomain
import SettingsDomain

public struct BatteryHealthUseCases: Sendable {
    public let startMonitoring: StartBatteryHealthMonitoringUseCase
    public let stopMonitoring: StopBatteryHealthMonitoringUseCase
    public let observeHealth: ObserveBikeBatteryHealthUseCase
    public let observeCaptures: ObserveBatteryDatasetCapturesUseCase
    public let observeSettings: ObserveAppSettingsUseCase
    public let prepareChargePowerControl: PrepareChargePowerControlUseCase
    public let setChargePowerLimit: SetChargePowerLimitUseCase
    public let setChargeTarget: SetChargeTargetUseCase

    public init(
        startMonitoring: StartBatteryHealthMonitoringUseCase,
        stopMonitoring: StopBatteryHealthMonitoringUseCase,
        observeHealth: ObserveBikeBatteryHealthUseCase,
        observeCaptures: ObserveBatteryDatasetCapturesUseCase,
        observeSettings: ObserveAppSettingsUseCase,
        prepareChargePowerControl: PrepareChargePowerControlUseCase,
        setChargePowerLimit: SetChargePowerLimitUseCase,
        setChargeTarget: SetChargeTargetUseCase
    ) {
        self.startMonitoring = startMonitoring
        self.stopMonitoring = stopMonitoring
        self.observeHealth = observeHealth
        self.observeCaptures = observeCaptures
        self.observeSettings = observeSettings
        self.prepareChargePowerControl = prepareChargePowerControl
        self.setChargePowerLimit = setChargePowerLimit
        self.setChargeTarget = setChargeTarget
    }
}
