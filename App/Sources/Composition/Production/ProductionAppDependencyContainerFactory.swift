import BikeData
import BikeDiagnostics
import BikeDomain
import BLETraceDomain
import CoreLocation
import EnvironmentData
import EnvironmentDomain
import Foundation
import MaintenanceLog
import RideNavigationData
import SettingsData
import SettingsDomain
import VehicleSession

@MainActor
enum ProductionAppDependencyContainerFactory {
    static func makeDefault(
        maintenanceReminderScheduler: any MaintenanceReminderScheduling,
        storageFactory: ProductionAppStorageFactory = .live
    ) throws -> AppDependencyContainer {
        let storage = try storageFactory.make()
        let bikeSDKContainer = BikeSDKDependencyContainer()
        let bikeDataContainer = BikeDataDependencyContainer()
        let captureState = BLETraceCaptureState()
        let bleTraceRepository = BLETraceDependencyContainer().makeRepository(captureState: captureState)
        let client = bikeSDKContainer.makeBikeTelemetryClient(
            traceRecorder: bleTraceRepository, captureState: captureState
        )
        let profileRepository = UserDefaultsBikeProfileRepository(userDefaults: .standard)
        let repository = bikeDataContainer.makeBikeRepository(
            client: client,
            profileRepository: profileRepository,
            captureState: captureState
        )
        let session = BikeSession(
            repository: repository,
            pinDeriver: bikeDataContainer.makeBikePinDeriver()
        )
        let chargeControl = ChargeControlDependencyContainer().makeSession(
            repository: repository, captureState: captureState
        )
        let settingsRepository = makeSettingsRepository(profile: profileRepository)
        let deviceSpeedRepository = CoreLocationDeviceSpeedRepository(
            locationManager: CLLocationManager()
        )
        let rideTripRepository = storage.rides
        let maintenanceRepository = storage.maintenance
        let bikeLockCapabilityStore = BikeLockCapabilityStateStore()
        let sessionServices = makeSessionServices(
            repository: repository, profile: profileRepository, settings: settingsRepository,
            speed: deviceSpeedRepository, storage: storage
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
            maintenanceRepository: maintenanceRepository,
            sessionServices: sessionServices,
            onboardingContainer: BikeOnboardingDependencyContainer(),
            dashboardContainer: RideDashboardDependencyContainer(),
            appSettingsContainer: AppSettingsDependencyContainer(),
            dashboardCardSettingsContainer: DashboardCardSettingsDependencyContainer(),
            powerModeSettingsContainer: PowerModeSettingsDependencyContainer(),
            rideHistoryContainer: RideHistoryDependencyContainer(),
            maintenanceContainer: MaintenanceDependencyContainer(reminderScheduler: maintenanceReminderScheduler),
            bleTraceLogRepository: bleTraceRepository,
            incomingMapLinkStore: makeIncomingMapLinkStore(),
            bikeLockCredentialStore: makeBikeLockCredentialStore(),
            bikeLockAuthenticator: BikeLockAuthenticationFactory.makeAuthenticator(),
            bikeLockCapabilityStore: bikeLockCapabilityStore,
            startupPreparer: NoOpAppStartupPreparer()
        )
    }

    private static func makeSessionServices(
        repository: LiveBikeRepository,
        profile: any BikeProfileRepository,
        settings: any AppSettingsRepository,
        speed: any DeviceSpeedRepository,
        storage: ProductionAppStorage
    ) -> AppSessionServices {
        AppSessionDependencyContainer.makeServices(dependencies: .init(
            repository: repository,
            profileRepository: profile,
            settingsRepository: settings,
            deviceSpeedRepository: speed,
            deviceHeadingRepository: DeviceHeadingDependencyContainer.makeRepository(),
            motionCalibrationRepository: storage.calibration,
            imuProfile: makeIMUProfile(),
            rideTripRepository: storage.rides
        ))
    }

    private static func makeSettingsRepository(profile: any BikeProfileRepository) -> any AppSettingsRepository {
        AppSettingsRepositoryFactory.make(userDefaults: .standard, profileRepository: profile)
    }

    private static func makeBikeLockCredentialStore() -> KeychainBikeLockCredentialStore {
        KeychainBikeLockCredentialStore(service: "com.fenr.app.bike-lock")
    }

    private static func makeIMUProfile() -> BikeIMUProfile? {
        .productionV1
    }

    private static func makeIncomingMapLinkStore() -> UserDefaultsIncomingMapLinkStore {
        (try? UserDefaultsIncomingMapLinkStore.shared())
            ?? UserDefaultsIncomingMapLinkStore(
                userDefaults: .standard,
                encoder: JSONEncoder(),
                decoder: JSONDecoder()
            )
    }

}
