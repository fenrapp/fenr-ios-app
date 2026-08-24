import BikeData
import BikeDomain
import BikeSDK
import SettingsData

@MainActor
enum LiveWatchAppDependencyContainerFactory {
    static func makeDefault() -> WatchAppDependencyContainer {
        let client = BikeTelemetryClientFactory.makeDefault(centralRestorationIdentifier: nil)
        return WatchAppDependencyContainer(
            repository: LiveBikeRepositoryFactory.makeDefault(client: client),
            profileRepository: UserDefaultsBikeProfileRepository(),
            settingsRepository: UserDefaultsAppSettingsRepository(),
            initialProfile: nil
        )
    }
}
