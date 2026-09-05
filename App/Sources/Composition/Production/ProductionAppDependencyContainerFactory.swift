import BikeData
import BikeDiagnostics
import BikeDomain
import BLETraceDomain
import CoreLocation
import EnvironmentData
import EnvironmentDomain
import Foundation
import MaintenanceData
import MaintenanceLog
import RideNavigationData
import RideSessionData
import SettingsData
import SettingsDomain
import VehicleSession

@MainActor
enum ProductionAppDependencyContainerFactory {
    static func makeDefault(
        maintenanceReminderScheduler: any MaintenanceReminderScheduling
    ) -> AppDependencyContainer {
        let bikeSDKContainer = BikeSDKDependencyContainer()
        let bikeDataContainer = BikeDataDependencyContainer()
        let bleTraceRepository = BLETraceDependencyContainer().makeRepository()
        let client = bikeSDKContainer.makeBikeTelemetryClient(traceRecorder: bleTraceRepository)
        let profileRepository = UserDefaultsBikeProfileRepository(userDefaults: .standard)
        let repository = bikeDataContainer.makeBikeRepository(
            client: client,
            profileRepository: profileRepository
        )
        let session = BikeSession(
            repository: repository,
            pinDeriver: bikeDataContainer.makeBikePinDeriver()
        )
        let chargeControl = ChargeControlDependencyContainer().makeSession(repository: repository)
        let settingsRepository = makeSettingsRepository(profile: profileRepository)
        let deviceSpeedRepository = CoreLocationDeviceSpeedRepository(
            locationManager: CLLocationManager()
        )
        let motionCalibrationRepository = makeMotionCalibrationRepository()
        let rideTripRepository = makeRideTripRepository()
        let maintenanceRepository = makeMaintenanceRepository()
        let bikeLockCapabilityStore = BikeLockCapabilityStateStore()
        let sessionServices = AppSessionDependencyContainer.makeServices(
            dependencies: .init(
                repository: repository,
                profileRepository: profileRepository,
                settingsRepository: settingsRepository,
                deviceSpeedRepository: deviceSpeedRepository,
                deviceHeadingRepository: DeviceHeadingDependencyContainer.makeRepository(),
                motionCalibrationRepository: motionCalibrationRepository,
                imuProfile: makeIMUProfile(),
                rideTripRepository: rideTripRepository
            )
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
            bikeLockAuthenticator: LocalAuthenticationBikeLockAuthenticator(),
            bikeLockCapabilityStore: bikeLockCapabilityStore,
            startupPreparer: NoOpAppStartupPreparer()
        )
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

    private static func makeRideTripRepository() -> SwiftDataRideTripRepository {
        do {
            let modelContainer = try SwiftDataRideTripRepository.makeModelContainer()
            return SwiftDataRideTripRepository(
                modelContainer: modelContainer,
                mapper: RideTripRecordMapper(),
                energyBucketMapper: RideEnergyBucketRecordMapper()
            )
        } catch {
            preconditionFailure("Unable to create the ride trip store: \(error)")
        }
    }

    private static func makeMaintenanceRepository() -> SwiftDataMaintenanceRepository {
        do {
            return try MaintenanceRepositoryFactory.make()
        } catch {
            preconditionFailure("Unable to create the maintenance store: \(error)")
        }
    }

    private static func makeMotionCalibrationRepository() -> SwiftDataVehicleMotionCalibrationRepository {
        do {
            return try SwiftDataVehicleMotionCalibrationRepository(
                mapper: VehicleMotionCalibrationRecordMapper()
            )
        } catch {
            preconditionFailure("Unable to create the motion calibration store: \(error)")
        }
    }

}
