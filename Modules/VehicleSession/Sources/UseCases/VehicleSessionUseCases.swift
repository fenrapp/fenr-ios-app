import BikeDomain
import EnvironmentDomain
import SettingsDomain

public struct VehicleSessionUseCases: Sendable {
    let observeTelemetry: ObserveBikeTelemetryUseCase
    let observeConnection: ObserveBikeConnectionUseCase
    let observeSettings: ObserveAppSettingsUseCase
    let observeDeviceSpeed: ObserveDeviceSpeedUseCase
    let observeIMU: ObserveBikeIMUUseCase
    let startIMUMonitoring: StartBikeIMUMonitoringUseCase
    let stopIMUMonitoring: StopBikeIMUMonitoringUseCase
    let loadMotionCalibration: LoadVehicleMotionCalibrationUseCase
    let saveMotionCalibration: SaveVehicleMotionCalibrationUseCase
    let observeBikeProfile: ObserveBikeProfileUseCase
    let observeBatteryHealth: ObserveBikeBatteryHealthUseCase
    let startBatteryHealthMonitoring: StartBatteryHealthMonitoringUseCase
    let stopBatteryHealthMonitoring: StopBatteryHealthMonitoringUseCase
    let readBikeStatusSnapshot: ReadBikeStatusSnapshotUseCase
    let refreshPowerModeConfiguration: RefreshBikePowerModeConfigurationUseCase?
    let refreshTractionControlConfiguration: RefreshBikeTractionControlConfigurationUseCase?

    public init(
        observeTelemetry: ObserveBikeTelemetryUseCase,
        observeConnection: ObserveBikeConnectionUseCase,
        observeSettings: ObserveAppSettingsUseCase,
        observeDeviceSpeed: ObserveDeviceSpeedUseCase,
        observeIMU: ObserveBikeIMUUseCase,
        startIMUMonitoring: StartBikeIMUMonitoringUseCase,
        stopIMUMonitoring: StopBikeIMUMonitoringUseCase,
        loadMotionCalibration: LoadVehicleMotionCalibrationUseCase,
        saveMotionCalibration: SaveVehicleMotionCalibrationUseCase,
        observeBikeProfile: ObserveBikeProfileUseCase,
        observeBatteryHealth: ObserveBikeBatteryHealthUseCase,
        startBatteryHealthMonitoring: StartBatteryHealthMonitoringUseCase,
        stopBatteryHealthMonitoring: StopBatteryHealthMonitoringUseCase,
        readBikeStatusSnapshot: ReadBikeStatusSnapshotUseCase,
        refreshPowerModeConfiguration: RefreshBikePowerModeConfigurationUseCase? = nil,
        refreshTractionControlConfiguration: RefreshBikeTractionControlConfigurationUseCase? = nil
    ) {
        self.observeTelemetry = observeTelemetry
        self.observeConnection = observeConnection
        self.observeSettings = observeSettings
        self.observeDeviceSpeed = observeDeviceSpeed
        self.observeIMU = observeIMU
        self.startIMUMonitoring = startIMUMonitoring
        self.stopIMUMonitoring = stopIMUMonitoring
        self.loadMotionCalibration = loadMotionCalibration
        self.saveMotionCalibration = saveMotionCalibration
        self.observeBikeProfile = observeBikeProfile
        self.observeBatteryHealth = observeBatteryHealth
        self.startBatteryHealthMonitoring = startBatteryHealthMonitoring
        self.stopBatteryHealthMonitoring = stopBatteryHealthMonitoring
        self.readBikeStatusSnapshot = readBikeStatusSnapshot
        self.refreshPowerModeConfiguration = refreshPowerModeConfiguration
        self.refreshTractionControlConfiguration = refreshTractionControlConfiguration
    }
}
