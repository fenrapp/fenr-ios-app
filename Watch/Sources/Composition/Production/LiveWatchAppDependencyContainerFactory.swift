import BikeData
import BikeDomain
import BikeSDK
import BLETraceDomain
import SettingsData

@MainActor
enum LiveWatchAppDependencyContainerFactory {
    static func makeDefault() -> WatchAppDependencyContainer {
        let client = BikeTelemetryClientFactory.makeDefault(
            traceRecorder: NoOpBLETraceRepository(),
            centralRestorationIdentifier: nil,
            automaticallyRetryPairing: true,
            authenticationLinkRecoveryEnabled: true
        )
        return WatchAppDependencyContainer(
            repository: LiveBikeRepositoryFactory.makeDefault(client: client),
            profileRepository: UserDefaultsBikeProfileRepository(),
            settingsRepository: UserDefaultsAppSettingsRepository(),
            initialProfile: nil
        )
    }
}
