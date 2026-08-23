@preconcurrency import Foundation
import SettingsData
import SettingsDomain
import Testing

@MainActor
@Suite("App settings persistence")
struct UserDefaultsAppSettingsRepositoryTests {
    @Test("Returns defaults until settings are saved")
    func returnsDefaults() async {
        let repository = UserDefaultsAppSettingsRepository(userDefaults: makeDefaults())
        #expect(await repository.load() == AppSettings())
    }

    @Test("Persists selected speed source, units, and battery capacity")
    func persistsSettings() async {
        let defaults = makeDefaults()
        let repository = UserDefaultsAppSettingsRepository(userDefaults: defaults)
        let expected = AppSettings(
            speedSource: .hybrid,
            measurementSystem: .imperial,
            batteryPackCapacity: .sixPointEightKilowattHours
        )

        await repository.save(expected)

        #expect(await UserDefaultsAppSettingsRepository(userDefaults: defaults).load() == expected)
    }

    private func makeDefaults() -> UserDefaults {
        let name = "UserDefaultsAppSettingsRepositoryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}
