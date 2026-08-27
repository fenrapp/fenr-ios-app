import BikeDomain
import EnvironmentDomain
import Foundation
import RuntimeConfiguration
import SettingsDomain
import VehicleSession

enum VehicleSessionDependencyContainer {
    static func makeService(
        repository: any BikeRepository & BikeBatteryHealthRepository,
        profileRepository: any BikeProfileRepository,
        settingsRepository: any AppSettingsRepository,
        deviceSpeedRepository: any DeviceSpeedRepository
    ) -> any VehicleSessionService {
        LiveVehicleSessionService(
            useCases: .init(
                observeTelemetry: .init(repository: repository),
                observeConnection: .init(repository: repository),
                observeSettings: .init(repository: settingsRepository),
                observeDeviceSpeed: .init(repository: deviceSpeedRepository),
                observeBikeProfile: .init(repository: profileRepository),
                observeBatteryHealth: .init(repository: repository),
                startBatteryHealthMonitoring: .init(repository: repository),
                stopBatteryHealthMonitoring: .init(repository: repository),
                readBikeStatusSnapshot: .init(repository: repository)
            ),
            speedResolver: .init(
                now: Date.init,
                maximumAccuracyMetersPerSecond: Constants.maximumGPSAccuracyMetersPerSecond,
                maximumSampleAge: FENRRuntimeConstants.RideDashboard.deviceSpeedMaximumSampleAge
            )
        )
    }
}

private extension VehicleSessionDependencyContainer {
    enum Constants {
        static let maximumGPSAccuracyMetersPerSecond: Double = 5
    }
}
