import BikeDomain
import BikeEmulator
import Foundation
import SettingsData

@MainActor
enum DebugWatchAppDependencyContainerFactory {
    static func makeDefault(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> WatchAppDependencyContainer {
        let repository = BikeEmulatorRepositoryFactory.make(
            scenario: scenario(from: arguments)
        )
        return WatchAppDependencyContainer(
            repository: repository,
            profileRepository: WatchDebugProfileRepository(),
            settingsRepository: UserDefaultsAppSettingsRepository(userDefaults: .standard),
            initialProfile: BikeProfile(vin: BikeEmulatorIdentity.vin)
        )
    }

    private static func scenario(from arguments: [String]) -> BikeEmulatorScenario {
        guard let argument = arguments.first(where: {
            $0.hasPrefix(Constants.scenarioArgumentPrefix)
        }) else {
            return .charging
        }

        let rawValue = String(argument.dropFirst(Constants.scenarioArgumentPrefix.count))
        return BikeEmulatorScenario(rawValue: rawValue) ?? .charging
    }

    private enum Constants {
        static let scenarioArgumentPrefix = "-debugScenario="
    }
}
