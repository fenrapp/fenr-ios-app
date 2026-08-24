import BikeDomain
import BikeEmulator
import SettingsData

@MainActor
enum DebugWatchAppDependencyContainerFactory {
    static func makeDefault() -> WatchAppDependencyContainer {
        let repository = BikeEmulatorRepository(scenario: .riding)
        return WatchAppDependencyContainer(
            repository: repository,
            profileRepository: WatchDebugProfileRepository(),
            settingsRepository: UserDefaultsAppSettingsRepository(),
            initialProfile: BikeProfile(vin: BikeEmulatorIdentity.vin)
        )
    }
}
