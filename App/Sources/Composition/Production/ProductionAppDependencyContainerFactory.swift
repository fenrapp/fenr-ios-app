import BikeData
import BikeDiagnostics
import BikeDomain
import CoreLocation
import EnvironmentData
import Foundation
import RideSessionData
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
        let settingsRepository = UserDefaultsAppSettingsRepository()
        let deviceSpeedRepository = CoreLocationDeviceSpeedRepository(
            locationManager: CLLocationManager()
        )
        let rideTripRepository = makeRideTripRepository()
        let sessionServices = AppSessionDependencyContainer.makeServices(
            repository: repository,
            profileRepository: profileRepository,
            settingsRepository: settingsRepository,
            deviceSpeedRepository: deviceSpeedRepository,
            rideTripRepository: rideTripRepository
        )
        return AppDependencyContainer(
            diagnosticsContainer: BikeDiagnosticsDependencyContainer(),
            batteryHealthContainer: BatteryHealthDependencyContainer(),
            session: session,
            chargeControlSession: chargeControl,
            profileRepository: profileRepository,
            settingsRepository: settingsRepository,
            deviceSpeedRepository: deviceSpeedRepository,
            rideTripRepository: rideTripRepository,
            sessionServices: sessionServices,
            onboardingContainer: BikeOnboardingDependencyContainer(),
            dashboardContainer: RideDashboardDependencyContainer(),
            appSettingsContainer: AppSettingsDependencyContainer()
        )
    }

    private static func makeRideTripRepository() -> SwiftDataRideTripRepository {
        do {
            return try SwiftDataRideTripRepository(
                mapper: RideTripRecordMapper()
            )
        } catch {
            preconditionFailure("Unable to create the ride trip store: \(error)")
        }
    }
}
