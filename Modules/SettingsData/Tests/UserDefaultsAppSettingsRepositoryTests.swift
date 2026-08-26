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
        let suiteName = makeSuiteName()
        let repository = UserDefaultsAppSettingsRepository(
            userDefaults: makeDefaults(suiteName: suiteName)
        )
        let expected = AppSettings(
            speedSource: .hybrid,
            measurementSystem: .imperial,
            batteryPackCapacity: .sixPointEightKilowattHours
        )

        await repository.save(expected)

        let reloadedRepository = UserDefaultsAppSettingsRepository(
            userDefaults: makeDefaults(suiteName: suiteName, clearsDomain: false)
        )
        #expect(await reloadedRepository.load() == expected)
    }

    @Test("Does not notify observers when the saved settings are unchanged")
    func skipsDuplicateSettingsNotifications() async {
        let repository = UserDefaultsAppSettingsRepository(userDefaults: makeDefaults())
        let stream = await repository.observe()
        var iterator = stream.makeAsyncIterator()
        _ = await iterator.next()
        let metric = AppSettings(measurementSystem: .metric)
        let imperial = AppSettings(measurementSystem: .imperial)

        await repository.save(metric)
        #expect(await iterator.next() == metric)
        await repository.save(metric)
        await repository.save(imperial)

        #expect(await iterator.next() == imperial)
    }

    nonisolated private func makeSuiteName() -> String {
        "UserDefaultsAppSettingsRepositoryTests.\(UUID().uuidString)"
    }

    nonisolated private func makeDefaults(
        suiteName: String = "UserDefaultsAppSettingsRepositoryTests.\(UUID().uuidString)",
        clearsDomain: Bool = true
    ) -> UserDefaults {
        let defaults = UserDefaults(suiteName: suiteName)!
        if clearsDomain {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }
}
