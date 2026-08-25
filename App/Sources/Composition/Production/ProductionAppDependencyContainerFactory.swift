import BikeData
import BikeDiagnostics
import BikeDomain
import CoreLocation
import EnvironmentData
import Foundation
import SettingsData

@MainActor
enum ProductionAppDependencyContainerFactory {
    static func makeDefault() -> AppDependencyContainer {
        let bikeSDKContainer = BikeSDKDependencyContainer()
        let bikeDataContainer = BikeDataDependencyContainer()
        let client = bikeSDKContainer.makeBikeTelemetryClient()
        let profileRepository = UserDefaultsBikeProfileRepository()
        let repository = bikeDataContainer.makeBikeRepository(
            client: client,
            profileRepository: profileRepository
        )
        let session = BikeSession(
            repository: repository,
            pinDeriver: bikeDataContainer.makeBikePinDeriver()
        )
        let chargeControl = ChargeControlDependencyContainer().makeSession(repository: repository)
        return AppDependencyContainer(
            diagnosticsContainer: BikeDiagnosticsDependencyContainer(),
            batteryHealthContainer: BatteryHealthDependencyContainer(),
            session: session,
            chargeControlSession: chargeControl,
            profileRepository: profileRepository,
            settingsRepository: UserDefaultsAppSettingsRepository(),
            deviceSpeedRepository: CoreLocationDeviceSpeedRepository(
                locationManager: CLLocationManager()
            ),
            onboardingContainer: BikeOnboardingDependencyContainer(),
            dashboardContainer: RideDashboardDependencyContainer(),
            chargingDashboardContainer: ChargingDashboardDependencyContainer(),
            appSettingsContainer: AppSettingsDependencyContainer()
        )
    }
}
