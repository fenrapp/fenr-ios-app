import BikeEmulator
import Foundation

struct DebugScenarioStore {
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    func load() -> BikeEmulatorScenario {
        guard
            let rawValue = userDefaults.string(forKey: Constants.scenarioKey),
            let scenario = BikeEmulatorScenario(rawValue: rawValue)
        else {
            return .charging
        }
        return scenario
    }

    func save(_ scenario: BikeEmulatorScenario) {
        userDefaults.set(scenario.rawValue, forKey: Constants.scenarioKey)
    }

    private enum Constants {
        static let scenarioKey = "fenr.debug.selectedScenario"
    }
}
