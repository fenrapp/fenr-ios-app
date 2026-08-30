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
                observeIMU: .init(repository: dependencies.imuRepository),
                startIMUMonitoring: .init(repository: dependencies.imuRepository),
                stopIMUMonitoring: .init(repository: dependencies.imuRepository),
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
                maximumSampleAge: FENRRuntimeConstants.VehicleSession.locationSampleMaximumAge
            ),
            motionEstimator: .init(
                profile: dependencies.imuProfile,
                now: Date.init,
                maximumSampleAge: Constants.maximumMotionSampleAge,
                minimumGPSCourseSpeedKilometersPerHour: Constants.minimumGPSCourseSpeedKilometersPerHour,
                maximumGPSCourseAccuracyDegrees: Constants.maximumGPSCourseAccuracyDegrees,
                maximumLocationSampleAge: FENRRuntimeConstants.VehicleSession.locationSampleMaximumAge
            )
        )
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

private extension VehicleSessionDependencyContainer {
    enum Constants {
        static let maximumGPSAccuracyMetersPerSecond: Double = 5
        static let maximumMotionSampleAge: TimeInterval = 0.75
        static let minimumGPSCourseSpeedKilometersPerHour: Double = 5
        static let maximumGPSCourseAccuracyDegrees: Double = 35
    }
}
