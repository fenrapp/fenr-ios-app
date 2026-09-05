import BikeData
import BikeDomain
import BikeSDK
import BLETraceDomain
import Foundation
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
        let profileRepository = UserDefaultsBikeProfileRepository(userDefaults: .standard)
        return WatchAppDependencyContainer(
            repository: LiveBikeRepositoryFactory.makeDefault(client: client),
            profileRepository: profileRepository,
            settingsRepository: AppSettingsRepositoryFactory.make(
                userDefaults: .standard, profileRepository: profileRepository
            ),
            initialProfile: nil
        )
    }
}
