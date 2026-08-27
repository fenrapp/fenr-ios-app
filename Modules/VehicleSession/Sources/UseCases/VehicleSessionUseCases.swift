import BikeDomain
import EnvironmentDomain
import SettingsDomain

public struct VehicleSessionUseCases: Sendable {
    let observeTelemetry: ObserveBikeTelemetryUseCase
    let observeConnection: ObserveBikeConnectionUseCase
    let observeSettings: ObserveAppSettingsUseCase
    let observeDeviceSpeed: ObserveDeviceSpeedUseCase
    let observeBikeProfile: ObserveBikeProfileUseCase
    let observeBatteryHealth: ObserveBikeBatteryHealthUseCase
    let startBatteryHealthMonitoring: StartBatteryHealthMonitoringUseCase
    let stopBatteryHealthMonitoring: StopBatteryHealthMonitoringUseCase
    let readBikeStatusSnapshot: ReadBikeStatusSnapshotUseCase

    public init(
        observeTelemetry: ObserveBikeTelemetryUseCase,
        observeConnection: ObserveBikeConnectionUseCase,
        observeSettings: ObserveAppSettingsUseCase,
        observeDeviceSpeed: ObserveDeviceSpeedUseCase,
        observeBikeProfile: ObserveBikeProfileUseCase,
        observeBatteryHealth: ObserveBikeBatteryHealthUseCase,
        startBatteryHealthMonitoring: StartBatteryHealthMonitoringUseCase,
        stopBatteryHealthMonitoring: StopBatteryHealthMonitoringUseCase,
        readBikeStatusSnapshot: ReadBikeStatusSnapshotUseCase
    ) {
        self.observeTelemetry = observeTelemetry
        self.observeConnection = observeConnection
        self.observeSettings = observeSettings
        self.observeDeviceSpeed = observeDeviceSpeed
        self.observeBikeProfile = observeBikeProfile
        self.observeBatteryHealth = observeBatteryHealth
        self.startBatteryHealthMonitoring = startBatteryHealthMonitoring
        self.stopBatteryHealthMonitoring = stopBatteryHealthMonitoring
        self.readBikeStatusSnapshot = readBikeStatusSnapshot
    }
}
