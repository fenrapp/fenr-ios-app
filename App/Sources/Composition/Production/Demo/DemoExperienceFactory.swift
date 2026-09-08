import BikeData
import BikeDemo
import BikeDiagnostics
import BikeDomain
import BikeEmulator
import BLETraceDomain
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
struct DemoExperienceFactory {
    let fileManager: FileManager
    let baseDirectory: URL
    let notifications: any DemoNotificationManaging
    let makeDeviceSpeedRepository: @MainActor () -> any DeviceSpeedRepository
    let makeCredentialStore: @MainActor (String) -> any BikeLockCredentialStoring

    func make(identity: DemoIdentity) async throws -> AppExperience {
        let storage = try makeStorage(identity: identity)
        let stateStore = DemoStateStore(
            vin: identity.vin, defaults: storage.defaults,
            encoder: JSONEncoder(), decoder: JSONDecoder(), lock: NSLock()
        )
        let state = try stateStore.load()
        let repository = BikeEmulatorRepositoryFactory.make(configuration: .init(
            vin: identity.vin, peripheralIdentifier: identity.id, initialState: state,
            isDemo: true, persist: { stateStore.save($0) }
        ))
        let profileRepository = UserDefaultsBikeProfileRepository(userDefaults: try makeDefaults(identity: identity))
        if await profileRepository.loadProfile() == nil {
            await profileRepository.saveProfile(BikeProfile(
                vin: identity.vin, declaredPowerTier: .alpha,
                alphaEvidence: [.powerAboveStandard, .tractionControlConfigured], alphaDetectedAt: identity.createdAt
            ))
        }
        await prepareCalibration(storage: storage, identity: identity)
        try await DemoSeedPreparer(
            identity: identity, defaults: storage.defaults, rides: storage.rides, maintenance: storage.maintenance
        ).prepare()
        let root = try makeContainer(
            identity: identity, repository: repository, profileRepository: profileRepository, storage: storage
        ).makeRootDependencies()
        let mapper = BikeDemoPresentationMapper()
        let model = BikeDemoViewModel(
            viewState: mapper.map(state.scenario), useCases: BikeDemoUseCases(repository: repository), mapper: mapper
        )
        return AppExperience(
            id: identity.id, root: root, demoViewModel: model,
            close: {
                await model.stop()
                await root.shutDown()
                await repository.stop()
                stateStore.invalidate()
                await notifications.cancelAll(prefix: notificationPrefix(identity))
            },
            discard: { try await discard(identity: identity) }
        )
    }

    func discard(identity: DemoIdentity) async throws {
        await notifications.cancelAll(prefix: notificationPrefix(identity))
        try await makeCredentialStore(identity.credentialService)
            .removePIN(for: identity.vin)
        UserDefaults.standard.removePersistentDomain(forName: identity.suiteName)
        let directory = directory(for: identity)
        if fileManager.fileExists(atPath: directory.path) {
            try fileManager.removeItem(at: directory)
        }
    }

    private func makeStorage(identity: DemoIdentity) throws -> DemoStorage {
        guard let defaults = UserDefaults(suiteName: identity.suiteName) else {
            throw DemoPreparationError.unavailableStorage
        }
        let directory = directory(for: identity)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let rides = RideTripRepositoryFactory.make(
            modelContainer: try RideTripRepositoryFactory.makeModelContainer(
                storeURL: directory.appendingPathComponent("Rides.store")
            ),
            mapper: RideTripRecordMapper(), energyBucketMapper: RideEnergyBucketRecordMapper()
        )
        return DemoStorage(
            defaults: defaults, directory: directory, rides: rides,
            maintenance: try MaintenanceRepositoryFactory.make(
                storeURL: directory.appendingPathComponent("Maintenance.store")
            ),
            calibration: try VehicleMotionCalibrationRepositoryFactory.make(
                mapper: VehicleMotionCalibrationRecordMapper(),
                storeURL: directory.appendingPathComponent("Calibration.store")
            )
        )
    }

    private func prepareCalibration(storage: DemoStorage, identity: DemoIdentity) async {
        guard await storage.calibration.load(vin: identity.vin) == nil else { return }
        await storage.calibration.save(.init(
            vin: identity.vin, gyroscopeBiasXRaw: .zero, gyroscopeBiasYRaw: .zero, gyroscopeBiasZRaw: .zero,
            profileVersion: 1, calibratedAt: identity.createdAt
        ))
    }

    private func makeContainer(
        identity: DemoIdentity,
        repository: BikeEmulatorRepository,
        profileRepository: UserDefaultsBikeProfileRepository,
        storage: DemoStorage
    ) throws -> AppDependencyContainer {
        let settings = AppSettingsRepositoryFactory.make(
            userDefaults: try makeDefaults(identity: identity), profileRepository: profileRepository
        )
        let speed = makeDeviceSpeedRepository()
        let services = AppSessionDependencyContainer.makeServices(dependencies: .init(
            repository: repository, profileRepository: profileRepository,
            settingsRepository: settings, deviceSpeedRepository: speed,
            deviceHeadingRepository: DeviceHeadingDependencyContainer.makeRepository(),
            motionCalibrationRepository: storage.calibration, imuProfile: makeIMUProfile(),
            rideTripRepository: storage.rides
        ))
        let scheduler = DemoMaintenanceReminderScheduler(
            scheduler: notifications.makeScheduler(prefix: notificationPrefix(identity)),
            title: String(localized: .appDemoLabel)
        )
        return AppDependencyContainer(
            diagnosticsContainer: BikeDiagnosticsDependencyContainer(isDemo: true),
            batteryHealthContainer: BatteryHealthDependencyContainer(isDemo: true),
            session: BikeSession(
                repository: repository, pinDeriver: BikeDataDependencyContainer().makeBikePinDeriver()
            ),
            chargeControlSession: ChargeControlDependencyContainer().makeSession(repository: repository),
            profileRepository: profileRepository, settingsRepository: settings, deviceSpeedRepository: speed,
            rideTripRepository: storage.rides, maintenanceRepository: storage.maintenance, sessionServices: services,
            onboardingContainer: BikeOnboardingDependencyContainer(),
            dashboardContainer: RideDashboardDependencyContainer(),
            appSettingsContainer: AppSettingsDependencyContainer(),
            dashboardCardSettingsContainer: DashboardCardSettingsDependencyContainer(),
            powerModeSettingsContainer: PowerModeSettingsDependencyContainer(),
            rideHistoryContainer: RideHistoryDependencyContainer(),
            maintenanceContainer: MaintenanceDependencyContainer(
                reminderScheduler: scheduler
            ),
            bleTraceLogRepository: NoOpBLETraceRepository(),
            incomingMapLinkStore: UserDefaultsIncomingMapLinkStore(
                userDefaults: try makeDefaults(identity: identity), encoder: JSONEncoder(), decoder: JSONDecoder()
            ),
            bikeLockCredentialStore: makeCredentialStore(identity.credentialService),
            bikeLockAuthenticator: BikeLockAuthenticationFactory.makeAuthenticator(),
            bikeLockCapabilityStore: BikeLockCapabilityStateStore(),
            startupPreparer: NoOpAppStartupPreparer(),
            experienceOptions: .init(
                isDemo: true, routeDirectory: storage.directory.appendingPathComponent("Routes", isDirectory: true)
            )
        )
    }

    private func makeIMUProfile() -> BikeIMUProfile {
        .init(
            version: 1,
            accelerationTransform: .init(bikeX: .positiveX, bikeY: .positiveY, bikeZ: .positiveZ),
            gyroscopeTransform: .init(bikeX: .positiveX, bikeY: .positiveY, bikeZ: .positiveZ),
            gyroscopeDegreesPerSecondPerRawUnit: .init(x: 1, y: 1, z: 1),
            oneGRaw: 1_000
        )
    }

    nonisolated private func makeDefaults(identity: DemoIdentity) throws -> sending UserDefaults {
        guard let defaults = UserDefaults(suiteName: identity.suiteName) else {
            throw DemoPreparationError.unavailableStorage
        }
        return defaults
    }

    private func directory(for identity: DemoIdentity) -> URL {
        baseDirectory.appendingPathComponent(identity.id.uuidString, isDirectory: true)
    }

    private func notificationPrefix(_ identity: DemoIdentity) -> String {
        "demo.\(identity.id.uuidString).maintenance."
    }
}

private struct DemoStorage {
    let defaults: UserDefaults
    let directory: URL
    let rides: SwiftDataRideTripRepository
    let maintenance: SwiftDataMaintenanceRepository
    let calibration: SwiftDataVehicleMotionCalibrationRepository
}
