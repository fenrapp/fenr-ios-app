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
            return .riding
        }
        return scenario
    }

    func save(_ scenario: BikeEmulatorScenario) {
        userDefaults.set(scenario.rawValue, forKey: Constants.scenarioKey)
    }

    func loadPowerModePreset() -> BikeEmulatorPowerModePreset {
        userDefaults.string(forKey: Constants.powerModePresetKey)
            .flatMap(BikeEmulatorPowerModePreset.init(rawValue:)) ?? .standard
    }

    func save(_ preset: BikeEmulatorPowerModePreset) {
        userDefaults.set(preset.rawValue, forKey: Constants.powerModePresetKey)
    }

    func loadActiveMap() -> Int {
        let value = userDefaults.integer(forKey: Constants.activeMapKey)
        return 1 ... 5 ~= value ? value : 4
    }

    func saveActiveMap(_ map: Int) {
        userDefaults.set(map, forKey: Constants.activeMapKey)
    }

    private enum Constants {
        static let scenarioKey = "fenr.debug.selectedScenario"
        static let powerModePresetKey = "fenr.debug.powerModePreset"
        static let activeMapKey = "fenr.debug.activeMap"
    }
}
