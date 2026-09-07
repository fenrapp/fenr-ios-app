import BikeDomain
import BikeEmulator
import BLETraceDomain
import EnvironmentData
import EnvironmentDomain
import Foundation
import MaintenanceData
import MaintenanceDomain
import MaintenanceLog
import RideNavigationData
import RideSessionData
import RideSessionDomain
import SettingsData
import SettingsDomain

@MainActor
enum DebugAppDependencyContainerFactory {
    static func makeDefault(
        maintenanceReminderScheduler: any MaintenanceReminderScheduling
    ) -> DebugAppContext {
        make(
            userDefaults: .standard,
            arguments: ProcessInfo.processInfo.arguments,
            maintenanceReminderScheduler: maintenanceReminderScheduler
        )
    }

    static func make(
        userDefaults: UserDefaults,
        arguments: [String],
        maintenanceReminderScheduler: any MaintenanceReminderScheduling
    ) -> DebugAppContext {
        let environment = makeEnvironment(userDefaults: userDefaults, arguments: arguments)
        let userDefaults = environment.defaults
        let captureState = BLETraceCaptureState()
        let traceRepository = NoOpBLETraceRepository()
        let skipsOnboarding = arguments.contains(Constants.skipOnboardingArgument)
        let store = DebugScenarioStore(userDefaults: userDefaults)
        let launchConfiguration = makeLaunchConfiguration(arguments: arguments, store: store)
        let repository = BikeEmulatorRepositoryFactory.make(
            scenario: store.load(),
            powerModePreset: launchConfiguration.powerModePreset,
            activeMap: launchConfiguration.activeMap,
            diagnostics: BikeEmulatorDiagnostics(
                recorder: traceRepository, captureState: captureState,
                uptimeNanoseconds: { DispatchTime.now().uptimeNanoseconds }
            )
        )
        let initialProfile = environment.profileStore?.load()
            ?? (skipsOnboarding ? profile(for: launchConfiguration.powerModePreset) : nil)
        if let initialProfile { environment.profileStore?.save(initialProfile) }
        let profileRepository = DebugBikeProfileRepository(
            initialProfile: initialProfile, persistence: environment.profileStore
        )
        return DebugAppContext(
            container: makeContainer(
                repository: repository,
                profileRepository: profileRepository,
                maintenanceReminderScheduler: maintenanceReminderScheduler,
                diagnostics: DebugDiagnosticsContext(traceRepository: traceRepository, captureState: captureState),
                environment: environment
            ),
            scenarioController: DebugScenarioController(
                repository: repository,
                store: store,
                profileRepository: profileRepository,
                initialPowerModePreset: launchConfiguration.powerModePreset,
                initialMap: launchConfiguration.activeMap
            ),
            uiTestControls: environment.controls,
            navigationControls: environment.navigation?.controls
        )
    }

}

private extension DebugAppDependencyContainerFactory {
    static func makeEnvironment(userDefaults: UserDefaults, arguments: [String]) -> DebugLaunchEnvironment {
        do {
            let fileManager = FileManager.default
            let applicationSupport = try fileManager.url(
                for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
            )
            let session = try DebugUITestSession.parse(arguments: arguments, applicationSupport: applicationSupport)
            guard let session else {
                return DebugLaunchEnvironment(
                    defaults: userDefaults, uiTestSession: nil, profileStore: nil, controls: nil, navigation: nil,
                    forceOnboarding: !arguments.contains(Constants.skipOnboardingArgument)
                )
            }
            let defaults = try session.prepare(
                fileManager: fileManager, clearCredentials: DebugUITestCredentialReset.clear
            )
            return DebugLaunchEnvironment(
                defaults: defaults,
                uiTestSession: session,
                profileStore: DebugUITestProfileStore(
                    defaults: defaults, encoder: JSONEncoder(), decoder: JSONDecoder(), lock: NSLock()
                ),
                controls: DebugUITestControls(),
                navigation: DebugNavigationHarness.make(
                    directory: session.directory.appendingPathComponent("Routes", isDirectory: true)
                ),
                forceOnboarding: false
            )
        } catch {
            preconditionFailure("Unable to prepare the isolated UI test environment: \(error)")
        }
    }

    private static func makeLaunchConfiguration(
        arguments: [String],
        store: DebugScenarioStore
    ) -> DebugLaunchConfiguration {
        if let rawScenario = launchValue(after: Constants.scenarioArgument, in: arguments),
           let scenario = BikeEmulatorScenario(rawValue: rawScenario) {
            store.save(scenario)
        }
        let powerModePreset = launchValue(after: Constants.powerTierArgument, in: arguments)
            .flatMap(BikeEmulatorPowerModePreset.init(rawValue:)) ?? store.loadPowerModePreset()
        let activeMap = launchValue(after: Constants.mapArgument, in: arguments)
            .flatMap(Int.init).flatMap { 1 ... 5 ~= $0 ? $0 : nil } ?? store.loadActiveMap()
        return DebugLaunchConfiguration(powerModePreset: powerModePreset, activeMap: activeMap)
    }

    private static func makeContainer(
        repository: BikeEmulatorRepository,
        profileRepository: DebugBikeProfileRepository,
        maintenanceReminderScheduler: any MaintenanceReminderScheduling,
        diagnostics: DebugDiagnosticsContext,
        environment: DebugLaunchEnvironment
    ) -> AppDependencyContainer {
        let settingsRepository = makeSettingsRepository(
            profileRepository: profileRepository, session: environment.uiTestSession
        )
        let deviceSpeedRepository: any DeviceSpeedRepository
        if let navigation = environment.navigation {
            deviceSpeedRepository = navigation.deviceSpeedRepository
        } else {
            deviceSpeedRepository = DebugDeviceSpeedRepository()
        }
        let motionCalibrationRepository = makeMotionCalibrationRepository()
        let persistence = makePersistence(environment: environment)
        let sessionServices = AppSessionDependencyContainer.makeServices(
            dependencies: .init(
                repository: repository,
                profileRepository: profileRepository,
                settingsRepository: settingsRepository,
                deviceSpeedRepository: deviceSpeedRepository,
                motionCalibrationRepository: motionCalibrationRepository,
                imuProfile: .debug,
                rideTripRepository: persistence.rides
            )
        )
        let bikeLockCapabilityStore = BikeLockCapabilityStateStore()
        return AppDependencyContainer(
            diagnosticsContainer: BikeDiagnosticsDependencyContainer(),
            batteryHealthContainer: BatteryHealthDependencyContainer(),
            session: BikeSession(repository: repository, pinDeriver: DebugBikePinDeriver()),
            chargeControlSession: ChargeControlDependencyContainer().makeSession(
                repository: repository, captureState: diagnostics.captureState
            ),
            profileRepository: profileRepository,
            settingsRepository: settingsRepository,
            deviceSpeedRepository: deviceSpeedRepository,
            rideTripRepository: persistence.rides,
            maintenanceRepository: persistence.maintenance,
            sessionServices: sessionServices,
            onboardingContainer: BikeOnboardingDependencyContainer(),
            dashboardContainer: RideDashboardDependencyContainer(),
            appSettingsContainer: AppSettingsDependencyContainer(),
            dashboardCardSettingsContainer: DashboardCardSettingsDependencyContainer(),
            powerModeSettingsContainer: PowerModeSettingsDependencyContainer(),
            rideHistoryContainer: RideHistoryDependencyContainer(),
            maintenanceContainer: MaintenanceDependencyContainer(
                reminderScheduler: environment.uiTestSession == nil
                    ? maintenanceReminderScheduler : NoOpMaintenanceReminderScheduler()
            ),
            bleTraceLogRepository: diagnostics.traceRepository,
            incomingMapLinkStore: makeIncomingMapLinkStore(environment: environment),
            bikeLockCredentialStore: KeychainBikeLockCredentialStore(
                service: environment.uiTestSession?.credentialService ?? "com.fenr.app.debug.bike-lock"
            ),
            bikeLockAuthenticator: BikeLockAuthenticationFactory.makeAuthenticator(),
            bikeLockCapabilityStore: bikeLockCapabilityStore,
            startupPreparer: persistence.seeder,
            initialOnboardingVIN: BikeEmulatorIdentity.vin,
            forceOnboarding: environment.forceOnboarding,
            rideNavigationFactoryBuilder: environment.navigation?.makeFeatureFactory
        )
    }

    private static func makePersistence(environment: DebugLaunchEnvironment) -> DebugPersistenceContext {
        let rides = makeRideTripRepository(directory: environment.uiTestSession?.directory)
        let maintenance = makeMaintenanceRepository(directory: environment.uiTestSession?.directory)
        let rideTripRepository: any RideTripRepository
        let maintenanceRepository: any MaintenanceRepository
        if let controls = environment.controls {
            rideTripRepository = DebugUITestRideTripRepository(repository: rides, controls: controls)
            maintenanceRepository = DebugUITestMaintenanceRepository(repository: maintenance, controls: controls)
        } else {
            rideTripRepository = rides
            maintenanceRepository = maintenance
        }
        let now: @Sendable () -> Date
        if environment.uiTestSession == nil {
            now = Date.init
        } else {
            now = { Date(timeIntervalSince1970: 1_700_000_000) }
        }
        return DebugPersistenceContext(
            rides: rideTripRepository,
            maintenance: maintenanceRepository,
            seeder: DebugRideHistorySeeder(
                repository: rides,
                now: now
            )
        )
    }

    private static func makeSettingsRepository(
        profileRepository: DebugBikeProfileRepository,
        session: DebugUITestSession?
    ) -> any AppSettingsRepository {
        if let session {
            guard let defaults = UserDefaults(suiteName: session.suiteName) else {
                preconditionFailure("Unable to open isolated settings defaults")
            }
            return AppSettingsRepositoryFactory.make(userDefaults: defaults, profileRepository: profileRepository)
        }
        return AppSettingsRepositoryFactory.make(userDefaults: .standard, profileRepository: profileRepository)
    }

    private static func makeIncomingMapLinkStore(
        environment: DebugLaunchEnvironment
    ) -> UserDefaultsIncomingMapLinkStore {
        if let session = environment.uiTestSession {
            guard let defaults = UserDefaults(suiteName: session.suiteName) else {
                preconditionFailure("Unable to open isolated incoming-link defaults")
            }
            return UserDefaultsIncomingMapLinkStore(
                userDefaults: defaults, encoder: JSONEncoder(), decoder: JSONDecoder()
            )
        }
        return (try? UserDefaultsIncomingMapLinkStore.shared())
            ?? UserDefaultsIncomingMapLinkStore(
                userDefaults: .standard,
                encoder: JSONEncoder(),
                decoder: JSONDecoder()
            )
    }

    private static func launchValue(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }

    private static func profile(for preset: BikeEmulatorPowerModePreset) -> BikeProfile {
        let evidence: Set<BikeAlphaEvidence> = switch preset {
        case .alpha, .mismatch: [.powerAboveStandard, .tractionControlConfigured]
        case .standard, .claimedAlpha, .partial, .failure: []
        }
        return BikeProfile(
            vin: BikeEmulatorIdentity.vin,
            declaredPowerTier: preset.declaredTier,
            alphaEvidence: evidence,
            alphaDetectedAt: evidence.isEmpty ? nil : Date()
        )
    }

    private static func makeMotionCalibrationRepository() -> DebugVehicleMotionCalibrationRepository {
        DebugVehicleMotionCalibrationRepository(calibrations: [
            BikeEmulatorIdentity.vin: .init(
                vin: BikeEmulatorIdentity.vin,
                gyroscopeBiasXRaw: .zero, gyroscopeBiasYRaw: .zero, gyroscopeBiasZRaw: .zero,
                profileVersion: 1, calibratedAt: Date()
            )
        ])
    }

    private static func makeRideTripRepository(directory: URL?) -> SwiftDataRideTripRepository {
        do {
            let modelContainer = try RideTripRepositoryFactory.makeModelContainer(
                storeURL: directory?.appendingPathComponent("Rides.store")
            )
            let repository = RideTripRepositoryFactory.make(
                modelContainer: modelContainer,
                mapper: RideTripRecordMapper(),
                energyBucketMapper: RideEnergyBucketRecordMapper()
            )
            return repository
        } catch {
            preconditionFailure("Unable to create the debug ride trip store: \(error)")
        }
    }

    private static func makeMaintenanceRepository(directory: URL?) -> SwiftDataMaintenanceRepository {
        do {
            return try MaintenanceRepositoryFactory.make(
                storeURL: directory?.appendingPathComponent("Maintenance.store")
            )
        } catch {
            preconditionFailure("Unable to create the debug maintenance store: \(error)")
        }
    }

    private enum Constants {
        static let skipOnboardingArgument = "-skipOnboarding"
        static let powerTierArgument = "-debugPowerTier"
        static let mapArgument = "-debugMap"
        static let scenarioArgument = "-debugScenario"
    }
}

private struct DebugLaunchConfiguration {
    let powerModePreset: BikeEmulatorPowerModePreset
    let activeMap: Int
}

@MainActor
struct DebugAppContext {
    let container: AppDependencyContainer
    let scenarioController: DebugScenarioController
    let uiTestControls: DebugUITestControls?
    let navigationControls: DebugNavigationControls?
}

private struct DebugBikePinDeriver: BikePinDeriving {
    func derivePin(vin: String) -> String {
        "000000"
    }
}

private struct DebugDiagnosticsContext {
    let traceRepository: any BLETraceRecording & BLETraceLogRepository
    let captureState: BLETraceCaptureState
}

private struct DebugPersistenceContext {
    let rides: any RideTripRepository
    let maintenance: any MaintenanceRepository
    let seeder: DebugRideHistorySeeder
}
