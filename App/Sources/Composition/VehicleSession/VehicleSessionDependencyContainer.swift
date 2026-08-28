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
        return LiveVehicleSessionService(
            useCases: .init(
                observeTelemetry: .init(repository: repository),
                observeConnection: .init(repository: repository),
                observeSettings: .init(repository: dependencies.settingsRepository),
                observeDeviceSpeed: .init(repository: dependencies.deviceSpeedRepository),
                observeDeviceMotion: .init(repository: dependencies.deviceMotionRepository),
                loadMotionCalibration: .init(repository: dependencies.motionCalibrationRepository),
                saveMotionCalibration: .init(repository: dependencies.motionCalibrationRepository),
                observeBikeProfile: .init(repository: dependencies.profileRepository),
                observeBatteryHealth: .init(repository: repository),
                startBatteryHealthMonitoring: .init(repository: repository),
                stopBatteryHealthMonitoring: .init(repository: repository),
                readBikeStatusSnapshot: .init(repository: repository),
                refreshPowerModeConfiguration: .init(repository: repository),
                refreshTractionControlConfiguration: .init(repository: repository)
            ),
            speedResolver: .init(
                now: Date.init,
                maximumAccuracyMetersPerSecond: Constants.maximumGPSAccuracyMetersPerSecond,
                maximumSampleAge: FENRRuntimeConstants.RideDashboard.deviceSpeedMaximumSampleAge
            ),
            motionEstimator: .init(
                now: Date.init,
                maximumSampleAge: Constants.maximumMotionSampleAge,
                minimumGPSCourseSpeedKilometersPerHour: Constants.minimumGPSCourseSpeedKilometersPerHour,
                maximumGPSCourseAccuracyDegrees: Constants.maximumGPSCourseAccuracyDegrees,
                smoothingFactor: Constants.motionSmoothingFactor,
                maximumLocationSampleAge: FENRRuntimeConstants.RideDashboard.deviceSpeedMaximumSampleAge
            )
        )
    }
}

struct VehicleSessionDependencies {
    let repository: any BikeRepository & BikeBatteryHealthRepository
    let profileRepository: any BikeProfileRepository
    let settingsRepository: any AppSettingsRepository
    let deviceSpeedRepository: any DeviceSpeedRepository
    let deviceMotionRepository: any DeviceMotionRepository
    let motionCalibrationRepository: any VehicleMotionCalibrationRepository
}

private extension VehicleSessionDependencyContainer {
    enum Constants {
        static let maximumGPSAccuracyMetersPerSecond: Double = 5
        static let maximumMotionSampleAge: TimeInterval = 0.75
        static let minimumGPSCourseSpeedKilometersPerHour: Double = 5
        static let maximumGPSCourseAccuracyDegrees: Double = 35
        static let motionSmoothingFactor: Double = 0.18
    }
}
