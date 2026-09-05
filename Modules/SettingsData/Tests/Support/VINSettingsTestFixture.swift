import BikeDomain
import Foundation
import SettingsData
import SettingsDomain
import TestSupport

@MainActor
struct VINSettingsTestFixture {
    let suite: String
    let profiles: SettingsProfileRepository
    let repository: any AppSettingsRepository

    init(vin: String? = "FENRTEST000000001", legacy: AppSettings? = nil) throws {
        suite = "fenr.tests.vin-settings.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        if let legacy { defaults.set(try JSONEncoder().encode(legacy), forKey: "fenr.app.settings") }
        profiles = SettingsProfileRepository(
            profile: vin.map { BikeProfile(vin: $0) }, events: TestEventHub(bufferingPolicy: .unbounded)
        )
        repository = AppSettingsRepositoryFactory.make(
            userDefaults: defaults, profileRepository: profiles
        )
    }

    func reopen() -> any AppSettingsRepository {
        AppSettingsRepositoryFactory.make(
            userDefaults: UserDefaults(suiteName: suite)!, profileRepository: profiles
        )
    }

    func cleanUp() { UserDefaults.standard.removePersistentDomain(forName: suite) }
}
