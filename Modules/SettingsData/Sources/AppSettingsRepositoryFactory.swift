import BikeDomain
import Foundation
import SettingsDomain

public enum AppSettingsRepositoryFactory {
    public static func make(
        userDefaults: sending UserDefaults,
        profileRepository: any BikeProfileRepository
    ) -> any AppSettingsRepository {
        VINScopedAppSettingsRepository(
            store: VINAppSettingsStore(defaults: userDefaults, encoder: JSONEncoder(), decoder: JSONDecoder()),
            profiles: profileRepository
        )
    }
}
