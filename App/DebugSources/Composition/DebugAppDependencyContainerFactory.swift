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

    static func make(userDefaults: UserDefaults) -> DebugAppContext {
        let repository = BikeEmulatorRepository(
            scenario: DebugScenarioStore(userDefaults: userDefaults).load()
        )
        let session = BikeSession(
            repository: repository,
            pinDeriver: DebugBikePinDeriver()
        )
        let container = AppDependencyContainer(
            diagnosticsContainer: BikeDiagnosticsDependencyContainer(),
            batteryHealthContainer: BatteryHealthDependencyContainer(),
            session: session,
            profileRepository: DebugBikeProfileRepository(),
            settingsRepository: UserDefaultsAppSettingsRepository(),
            deviceSpeedRepository: DebugDeviceSpeedRepository(),
            initialOnboardingVIN: BikeEmulatorIdentity.vin,
            forceOnboarding: true
        )
        return DebugAppContext(
            container: container,
            scenarioController: DebugScenarioController(
                repository: repository,
                store: DebugScenarioStore(userDefaults: userDefaults)
            )
        )
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
