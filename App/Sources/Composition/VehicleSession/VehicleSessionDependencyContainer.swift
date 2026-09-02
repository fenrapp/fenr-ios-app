import BikeDomain
import EnvironmentDomain
import Foundation
import RuntimeConfiguration
import SettingsDomain
import VehicleSession

enum VehicleSessionDependencyContainer {
    static func makeService(
        dependencies: VehicleSessionDependencies
    ) -> any VehicleSessionService {
        let repository = dependencies.repository
        let refreshPowerModeConfiguration = RefreshBikePowerModeConfigurationUseCase(
            repository: repository
        )
        let refreshTractionControlConfiguration = RefreshBikeTractionControlConfigurationUseCase(
            repository: repository
        )
        let observeBatteryHealth = ObserveBikeBatteryHealthUseCase(repository: repository)
        let startBatteryHealthMonitoring = StartBatteryHealthMonitoringUseCase(
            repository: repository
        )
        let stopBatteryHealthMonitoring = StopBatteryHealthMonitoringUseCase(
            repository: repository
        )
        return LiveVehicleSessionService(
            useCases: .init(
                observeTelemetry: .init(repository: repository),
                observeConnection: .init(repository: repository),
                observeSettings: .init(repository: dependencies.settingsRepository),
                observeDeviceSpeed: .init(repository: dependencies.deviceSpeedRepository),
                observeIMU: .init(repository: dependencies.imuRepository),
                startIMUMonitoring: .init(repository: dependencies.imuRepository),
                stopIMUMonitoring: .init(repository: dependencies.imuRepository),
                loadMotionCalibration: .init(repository: dependencies.motionCalibrationRepository),
                saveMotionCalibration: .init(repository: dependencies.motionCalibrationRepository),
                observeBikeProfile: .init(repository: dependencies.profileRepository),
                observeBatteryHealth: observeBatteryHealth,
                startBatteryHealthMonitoring: startBatteryHealthMonitoring,
                stopBatteryHealthMonitoring: stopBatteryHealthMonitoring,
                readBikeStatusSnapshot: .init(repository: repository),
                refreshPowerModeConfiguration: refreshPowerModeConfiguration,
                refreshTractionControlConfiguration: refreshTractionControlConfiguration
            ),
            powerModeRefreshCoordinator: .init(
                refreshPowerModeConfiguration: refreshPowerModeConfiguration,
                refreshTractionControlConfiguration: refreshTractionControlConfiguration
            ),
            batteryHealthMonitoringCoordinator: .init(
                observeBatteryHealth: observeBatteryHealth,
                startBatteryHealthMonitoring: startBatteryHealthMonitoring,
                stopBatteryHealthMonitoring: stopBatteryHealthMonitoring
            ),
            speedResolver: .init(
                now: Date.init,
                maximumAccuracyMetersPerSecond: Constants.maximumGPSAccuracyMetersPerSecond,
                maximumSampleAge: FENRRuntimeConstants.VehicleSession.locationSampleMaximumAge
            ),
            motionEstimator: makeMotionEstimator(dependencies: dependencies),
            sleep: { duration in try await Task.sleep(for: duration) }
        )
    }

    private static func makeMotionEstimator(
        dependencies: VehicleSessionDependencies
    ) -> VehicleMotionEstimator {
        VehicleMotionEstimator(
            profile: dependencies.imuProfile,
            now: Date.init,
            maximumSampleAge: Constants.maximumMotionSampleAge,
            attitudeFilter: .init(),
            calibrationTracker: .init(),
            locationResolver: .init(
                now: Date.init,
                maximumSampleAge: FENRRuntimeConstants.VehicleSession.locationSampleMaximumAge,
                minimumCourseSpeedKilometersPerHour: Constants.minimumGPSCourseSpeedKilometersPerHour,
                maximumCourseAccuracyDegrees: Constants.maximumGPSCourseAccuracyDegrees
            )
        )
    }

    private enum Constants {
        static let maximumGPSAccuracyMetersPerSecond: Double = 5
        static let maximumMotionSampleAge: TimeInterval = 0.75
        static let minimumGPSCourseSpeedKilometersPerHour: Double = 5
        static let maximumGPSCourseAccuracyDegrees: Double = 35
    }
}

struct VehicleSessionDependencies {
    let repository: any BikeRepository & BikeBatteryHealthRepository
    let profileRepository: any BikeProfileRepository
    let settingsRepository: any AppSettingsRepository
    let deviceSpeedRepository: any DeviceSpeedRepository
    let imuRepository: any BikeIMURepository
    let motionCalibrationRepository: any VehicleMotionCalibrationRepository
    let imuProfile: BikeIMUProfile?
}
