import BikeDomain
import BikeEmulator
import EnvironmentData
import Foundation
import RideSessionData
import RideSessionDomain
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
        let settingsRepository = UserDefaultsAppSettingsRepository()
        let deviceSpeedRepository = DebugDeviceSpeedRepository()
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
            initialOnboardingVIN: BikeEmulatorIdentity.vin,
            forceOnboarding: forceOnboarding
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
            let repository = try SwiftDataRideTripRepository(
                mapper: RideTripRecordMapper()
            )
            Task { await seedEfficiencyHistoryIfNeeded(repository) }
            return repository
        } catch {
            preconditionFailure("Unable to create the debug ride trip store: \(error)")
        }
    }

    private static func seedEfficiencyHistoryIfNeeded(
        _ repository: SwiftDataRideTripRepository
    ) async {
        let vin = BikeEmulatorIdentity.vin
        guard await repository.loadCompletedTrips(vin: vin).count < Constants.efficiencySeedTripCount else {
            return
        }
        let now = Date()
        for index in 0 ..< Constants.efficiencySeedTripCount {
            let end = now.addingTimeInterval(-Double(Constants.efficiencySeedTripCount - index) * 3_600)
            let duration = 1_200.0 + Double(index * 45)
            let distance = 9.0 + Double(index) * 0.8
            let consumed = distance * (78.0 - Double(index) * 2.4) + 55
            let recovered = 35.0 + Double((index * 17) % 70)
            let trip = RideTrip(
                vehicleIdentity: .vin(vin),
                applicationSessionID: UUID(),
                startedAt: end.addingTimeInterval(-duration),
                updatedAt: end,
                startingOdometerKilometers: 1_700 + Double(index) * 20,
                distanceKilometers: distance,
                elapsedSeconds: duration,
                averageSpeedKilometersPerHour: distance / duration * 3_600,
                maximumSpeedKilometersPerHour: 88 + Double(index * 3),
                consumedEnergyWattHours: consumed,
                recoveredEnergyWattHours: recovered,
                electricalObservedSeconds: duration * 0.97,
                electricalExpectedSeconds: duration,
                maximumDischargePowerWatts: 15_000 + Double(index * 500),
                maximumRegenerationPowerWatts: 6_000 + Double(index * 300)
            )
            await repository.completeTrip(trip, at: end)
        }
    }

    private enum Constants {
        static let skipOnboardingArgument = "-skipOnboarding"
        static let powerTierArgument = "-debugPowerTier"
        static let mapArgument = "-debugMap"
        static let scenarioArgument = "-debugScenario"
        static let efficiencySeedTripCount = 10
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
