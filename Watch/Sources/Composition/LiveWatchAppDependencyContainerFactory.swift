import BikeData
import BikeDomain
import BikeSDK

@MainActor
enum LiveWatchAppDependencyContainerFactory {
    static func makeDefault() -> WatchAppDependencyContainer {
        let client = BikeTelemetryClientFactory.makeDefault()
        return WatchAppDependencyContainer(
            repository: LiveBikeRepositoryFactory.makeDefault(client: client),
            profileRepository: UserDefaultsBikeProfileRepository(),
            initialProfile: nil
        )
    }
}
