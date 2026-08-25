import BikeDiagnostics
import BikeDomain
import BikeEmulator
import EnvironmentData
import Foundation
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
        let repository = BikeEmulatorRepositoryFactory.make(
            scenario: DebugScenarioStore(userDefaults: userDefaults).load()
        )
        let session = BikeSession(
            repository: repository,
            pinDeriver: DebugBikePinDeriver()
        )
        let chargeControl = ChargeControlDependencyContainer().makeSession(repository: repository)
        let container = AppDependencyContainer(
            diagnosticsContainer: BikeDiagnosticsDependencyContainer(),
            batteryHealthContainer: BatteryHealthDependencyContainer(),
            session: session,
            chargeControlSession: chargeControl,
            profileRepository: DebugBikeProfileRepository(
                initialProfile: skipsOnboarding ? .init(vin: BikeEmulatorIdentity.vin) : nil
            ),
            settingsRepository: UserDefaultsAppSettingsRepository(),
            deviceSpeedRepository: DebugDeviceSpeedRepository(),
            onboardingContainer: BikeOnboardingDependencyContainer(),
            dashboardContainer: RideDashboardDependencyContainer(),
            chargingDashboardContainer: ChargingDashboardDependencyContainer(),
            appSettingsContainer: AppSettingsDependencyContainer(),
            initialOnboardingVIN: BikeEmulatorIdentity.vin,
            forceOnboarding: !skipsOnboarding
        )
        return DebugAppContext(
            container: container,
            scenarioController: DebugScenarioController(
                repository: repository,
                store: DebugScenarioStore(userDefaults: userDefaults)
            )
        )
    }

    private enum Constants {
        static let skipOnboardingArgument = "-skipOnboarding"
    }
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
