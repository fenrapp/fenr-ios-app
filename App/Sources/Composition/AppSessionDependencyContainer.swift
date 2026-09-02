import BikeDomain
import EnvironmentDomain
import Foundation
import RideSession
import RideSessionDomain
import SettingsDomain
import VehicleSession

struct AppSessionServices {
    let vehicle: any VehicleSessionService
    let ride: any RideSessionService
}

struct AppSessionDependencies {
    let repository: any BikeRepository & BikeIMURepository & BikeBatteryHealthRepository
    let profileRepository: any BikeProfileRepository
    let settingsRepository: any AppSettingsRepository
    let deviceSpeedRepository: any DeviceSpeedRepository
    let motionCalibrationRepository: any VehicleMotionCalibrationRepository
    let imuProfile: BikeIMUProfile?
    let rideTripRepository: any RideTripRepository
}

enum AppSessionDependencyContainer {
    static func makeServices(
        dependencies: AppSessionDependencies,
        applicationSessionID: UUID = UUID()
    ) -> AppSessionServices {
        let vehicleSession = VehicleSessionDependencyContainer.makeService(
            dependencies: .init(
                repository: dependencies.repository,
                profileRepository: dependencies.profileRepository,
                settingsRepository: dependencies.settingsRepository,
                deviceSpeedRepository: dependencies.deviceSpeedRepository,
                imuRepository: dependencies.repository,
                motionCalibrationRepository: dependencies.motionCalibrationRepository,
                imuProfile: dependencies.imuProfile
            )
        )
        let rideSession = RideSessionDependencyContainer.makeService(
            dependencies: .init(
                rideTripRepository: dependencies.rideTripRepository,
                applicationSessionID: applicationSessionID
            ),
            vehicleSession: vehicleSession
        )
        return AppSessionServices(vehicle: vehicleSession, ride: rideSession)
    }
}
