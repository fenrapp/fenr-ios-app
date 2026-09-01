import BikeDomain
import BikeEmulator
import BLETraceDomain
import EnvironmentData
import EnvironmentDomain
import Foundation
import RideNavigationData
import RideSessionData
import SettingsData

@MainActor
enum DebugAppDependencyContainerFactory {
    static func makeDefault() -> DebugAppContext {
        make(userDefaults: .standard)
    }

    static func make(
        userDefaults: UserDefaults,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> DebugAppContext {
        let skipsOnboarding = arguments.contains(Constants.skipOnboardingArgument)
        let store = DebugScenarioStore(userDefaults: userDefaults)
        let launchConfiguration = makeLaunchConfiguration(arguments: arguments, store: store)
        let repository = BikeEmulatorRepositoryFactory.make(
            scenario: store.load(),
            powerModePreset: launchConfiguration.powerModePreset,
            activeMap: launchConfiguration.activeMap
        )
        let profileRepository = DebugBikeProfileRepository(
            initialProfile: skipsOnboarding
                ? profile(for: launchConfiguration.powerModePreset)
                : nil
        )
        return DebugAppContext(
            container: makeContainer(
                repository: repository,
                profileRepository: profileRepository,
                forceOnboarding: !skipsOnboarding
            ),
            scenarioController: DebugScenarioController(
                repository: repository,
                store: store,
                profileRepository: profileRepository,
                initialPowerModePreset: launchConfiguration.powerModePreset,
                initialMap: launchConfiguration.activeMap
            )
        )
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
        forceOnboarding: Bool
    ) -> AppDependencyContainer {
        let settingsRepository = UserDefaultsAppSettingsRepository(userDefaults: .standard)
        let deviceSpeedRepository = DebugDeviceSpeedRepository()
        let motionCalibrationRepository = DebugVehicleMotionCalibrationRepository(calibrations: [
            BikeEmulatorIdentity.vin: .init(
                vin: BikeEmulatorIdentity.vin,
                gyroscopeBiasXRaw: .zero,
                gyroscopeBiasYRaw: .zero,
                gyroscopeBiasZRaw: .zero,
                profileVersion: 1,
                calibratedAt: Date()
            )
        ])
        let rideTripRepository = makeRideTripRepository()
        let sessionServices = AppSessionDependencyContainer.makeServices(
            dependencies: .init(
                repository: repository,
                profileRepository: profileRepository,
                settingsRepository: settingsRepository,
                deviceSpeedRepository: deviceSpeedRepository,
                motionCalibrationRepository: motionCalibrationRepository,
                imuProfile: .debug,
                rideTripRepository: rideTripRepository
            )
        )
        let bikeLockCapabilityStore = BikeLockCapabilityStateStore()
        return AppDependencyContainer(
            diagnosticsContainer: BikeDiagnosticsDependencyContainer(),
            batteryHealthContainer: BatteryHealthDependencyContainer(),
            session: BikeSession(repository: repository, pinDeriver: DebugBikePinDeriver()),
            chargeControlSession: ChargeControlDependencyContainer().makeSession(repository: repository),
            profileRepository: profileRepository,
            settingsRepository: settingsRepository,
            deviceSpeedRepository: deviceSpeedRepository,
            rideTripRepository: rideTripRepository,
            sessionServices: sessionServices,
            onboardingContainer: BikeOnboardingDependencyContainer(),
            dashboardContainer: RideDashboardDependencyContainer(),
            appSettingsContainer: AppSettingsDependencyContainer(),
            dashboardCardSettingsContainer: DashboardCardSettingsDependencyContainer(),
            powerModeSettingsContainer: PowerModeSettingsDependencyContainer(),
            rideHistoryContainer: RideHistoryDependencyContainer(),
            bleTraceLogRepository: NoOpBLETraceRepository(),
            incomingMapLinkStore: makeIncomingMapLinkStore(),
            bikeLockCredentialStore: KeychainBikeLockCredentialStore(
                service: "com.fenr.app.debug.bike-lock"
            ),
            bikeLockAuthenticator: LocalAuthenticationBikeLockAuthenticator(),
            bikeLockCapabilityStore: bikeLockCapabilityStore,
            allowsExperimentalBikeLockControl: true,
            startupPreparer: DebugRideHistorySeeder(
                repository: rideTripRepository,
                now: Date.init
            ),
            initialOnboardingVIN: BikeEmulatorIdentity.vin,
            forceOnboarding: forceOnboarding
        )
    }

    private static func makeIncomingMapLinkStore() -> UserDefaultsIncomingMapLinkStore {
        (try? UserDefaultsIncomingMapLinkStore.shared())
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

    private static func makeRideTripRepository() -> SwiftDataRideTripRepository {
        do {
            let modelContainer = try SwiftDataRideTripRepository.makeModelContainer()
            let repository = SwiftDataRideTripRepository(
                modelContainer: modelContainer,
                mapper: RideTripRecordMapper(),
                energyBucketMapper: RideEnergyBucketRecordMapper()
            )
            return repository
        } catch {
            preconditionFailure("Unable to create the debug ride trip store: \(error)")
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
}

private struct DebugBikePinDeriver: BikePinDeriving {
    func derivePin(vin: String) -> String {
        "000000"
    }
}
