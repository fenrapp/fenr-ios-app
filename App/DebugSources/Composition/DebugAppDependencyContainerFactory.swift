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
        let profileRepository = DebugBikeProfileRepository(
            initialProfile: skipsOnboarding
                ? profile(for: launchConfiguration.powerModePreset)
                : nil
        )
        return DebugAppContext(
            container: makeContainer(
                repository: repository,
                profileRepository: profileRepository,
                forceOnboarding: !skipsOnboarding,
                maintenanceReminderScheduler: maintenanceReminderScheduler,
                diagnostics: DebugDiagnosticsContext(traceRepository: traceRepository, captureState: captureState)
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
        forceOnboarding: Bool,
        maintenanceReminderScheduler: any MaintenanceReminderScheduling,
        diagnostics: DebugDiagnosticsContext
    ) -> AppDependencyContainer {
        let settingsRepository = AppSettingsRepositoryFactory.make(
            userDefaults: .standard, profileRepository: profileRepository
        )
        let deviceSpeedRepository = DebugDeviceSpeedRepository()
        let motionCalibrationRepository = makeMotionCalibrationRepository()
        let rideTripRepository = makeRideTripRepository()
        let maintenanceRepository = makeMaintenanceRepository()
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
            chargeControlSession: ChargeControlDependencyContainer().makeSession(
                repository: repository, captureState: diagnostics.captureState
            ),
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
            bleTraceLogRepository: diagnostics.traceRepository,
            incomingMapLinkStore: makeIncomingMapLinkStore(),
            bikeLockCredentialStore: KeychainBikeLockCredentialStore(
                service: "com.fenr.app.debug.bike-lock"
            ),
            bikeLockAuthenticator: BikeLockAuthenticationFactory.makeAuthenticator(),
            bikeLockCapabilityStore: bikeLockCapabilityStore,
            startupPreparer: DebugRideHistorySeeder(
                repository: rideTripRepository,
                now: Date.init
            ),
            initialOnboardingVIN: BikeEmulatorIdentity.vin,
            forceOnboarding: forceOnboarding
        )
    }

    private static func makeIncomingMapLinkStore() -> UserDefaultsIncomingMapLinkStore {
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

    private static func makeRideTripRepository() -> SwiftDataRideTripRepository {
        do {
            let modelContainer = try RideTripRepositoryFactory.makeModelContainer()
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

    private static func makeMaintenanceRepository() -> SwiftDataMaintenanceRepository {
        do {
            return try MaintenanceRepositoryFactory.make()
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
