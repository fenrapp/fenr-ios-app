import BikeData
import BikeDiagnostics
import BikeDomain
import EnvironmentData
import Foundation
import SettingsData

@MainActor
enum ProductionAppDependencyContainerFactory {
    static func makeDefault() -> AppDependencyContainer {
        let starkProtocolContainer = StarkProtocolDependencyContainer()
        let bikeSDKContainer = BikeSDKDependencyContainer(
            starkProtocolContainer: starkProtocolContainer
        )
        let bikeDataContainer = BikeDataDependencyContainer()
        let client = bikeSDKContainer.makeBikeTelemetryClient()
        let repository = bikeDataContainer.makeBikeRepository(client: client)
        let session = BikeSession(
            repository: repository,
            pinDeriver: bikeDataContainer.makeBikePinDeriver()
        )
        return AppDependencyContainer(
            diagnosticsContainer: BikeDiagnosticsDependencyContainer(),
            batteryHealthContainer: BatteryHealthDependencyContainer(),
            session: session,
            profileRepository: UserDefaultsBikeProfileRepository(),
            settingsRepository: UserDefaultsAppSettingsRepository(),
            deviceSpeedRepository: CoreLocationDeviceSpeedRepository()
        )
    }
}
