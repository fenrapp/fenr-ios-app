import BikeDomain
import BikeEmulator
import SettingsData

@MainActor
enum DebugWatchAppDependencyContainerFactory {
    static func makeDefault() -> WatchAppDependencyContainer {
        let repository = BikeEmulatorRepositoryFactory.make(scenario: .riding)
        return WatchAppDependencyContainer(
            repository: repository,
            profileRepository: WatchDebugProfileRepository(),
            settingsRepository: UserDefaultsAppSettingsRepository(),
            initialProfile: BikeProfile(vin: BikeEmulatorIdentity.vin)
        )
    }
}
