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

    @Test("Persists selected dashboard, speed, units, and battery settings")
    func persistsSettings() async {
        let suiteName = makeSuiteName()
        let repository = UserDefaultsAppSettingsRepository(
            userDefaults: makeDefaults(suiteName: suiteName)
        )
        var cardConfiguration = DashboardCardConfiguration()
        cardConfiguration.setSectionOrder([
            .range, .navigation, .currentTrip, .efficiency, .systemHealth, .rideDynamics
        ])
        cardConfiguration.setSectionVisibility(false, id: .efficiency)
        let expected = AppSettings(
            speedSource: .hybrid,
            dashboardProgressBarMode: .speed,
            dashboardBatteryIndicatorMode: .estimatedRange,
            dashboardDeviceBatteryDisplayMode: .hidden,
            showsDashboardTemperatures: false,
            dashboardCardConfiguration: cardConfiguration,
            rideNavigation: RideNavigationSettings(
                avoidsTolls: true,
                avoidsHighways: true,
                preferredMapStyle: .satellite,
                mapOrientation: .northUp,
                miniMapPosition: MiniMapPosition(horizontalFraction: 0.28, verticalFraction: 0.73),
                miniMapScale: MiniMapScale(1.3),
                miniMapLayoutOrientation: .landscape
            ),
            measurementSystem: .imperial,
            batteryPackCapacity: .sixPointEightKilowattHours
        )

        await repository.save(expected)

        let reloadedRepository = UserDefaultsAppSettingsRepository(
            userDefaults: makeDefaults(suiteName: suiteName, clearsDomain: false)
        )
        #expect(await reloadedRepository.load() == expected)
    }

    @Test("Persists power mode names independently by bike and map")
    func persistsPowerModeNames() async throws {
        let suiteName = makeSuiteName()
        let repository = UserDefaultsAppSettingsRepository(
            userDefaults: makeDefaults(suiteName: suiteName)
        )
        var settings = AppSettings()
        try settings.setPowerModeName(
            try PowerModeName("ECO"),
            forVIN: "FENRTEST000000001",
            mapIndex: 0
        )
        try settings.setPowerModeName(
            try PowerModeName("Enduro"),
            forVIN: "FENRTEST000000002",
            mapIndex: 1
        )

        await repository.save(settings)

        let reloaded = await UserDefaultsAppSettingsRepository(
            userDefaults: makeDefaults(suiteName: suiteName, clearsDomain: false)
        ).load()
        #expect(reloaded.powerModeName(forVIN: "FENRTEST000000001", mapIndex: 0)?.value == "ECO")
        #expect(reloaded.powerModeName(forVIN: "FENRTEST000000002", mapIndex: 1)?.value == "Enduro")
        #expect(reloaded.powerModeName(forVIN: "FENRTEST000000001", mapIndex: 1) == nil)
    }

    @Test("Persists Bike Lock security independently by bike")
    func persistsBikeLockSettingsByBike() async {
        let suiteName = makeSuiteName()
        let repository = UserDefaultsAppSettingsRepository(
            userDefaults: makeDefaults(suiteName: suiteName)
        )
        var settings = AppSettings()
        settings.setBikeLockSettings(
            .init(securityMode: .pinAndFaceID),
            forVIN: "FENRTEST000000001"
        )

        await repository.save(settings)

        let reloaded = await UserDefaultsAppSettingsRepository(
            userDefaults: makeDefaults(suiteName: suiteName, clearsDomain: false)
        ).load()
        #expect(
            reloaded.bikeLockSettings(forVIN: "FENRTEST000000001").securityMode
                == .pinAndFaceID
        )
        #expect(
            reloaded.bikeLockSettings(forVIN: "FENRTEST000000002").securityMode
                == .notConfigured
        )
    }

    @Test("Does not notify observers when the saved settings are unchanged")
    func skipsDuplicateSettingsNotifications() async {
        let repository = UserDefaultsAppSettingsRepository(userDefaults: makeDefaults())
        let stream = await repository.observe()
        var iterator = stream.makeAsyncIterator()
        #expect(await iterator.next() == AppSettings())
        let metric = AppSettings(measurementSystem: .metric)
        let imperial = AppSettings(measurementSystem: .imperial)

        await repository.save(metric)
        #expect(await iterator.next() == metric)
        await repository.save(metric)
        await repository.save(imperial)

        #expect(await iterator.next() == imperial)
    }

    @Test("Loads the legacy blob from the stable settings key without rewriting it")
    func loadsLegacyBlobFromStableKey() async {
        let suiteName = makeSuiteName()
        let setupDefaults = makeDefaults(suiteName: suiteName)
        setupDefaults.set(
            AppSettingsPersistenceFixtures.legacySettingsData,
            forKey: AppSettingsPersistenceFixtures.settingsKey
        )
        let repository = UserDefaultsAppSettingsRepository(
            userDefaults: makeDefaults(suiteName: suiteName, clearsDomain: false)
        )

        let settings = await repository.load()
        let verificationDefaults = makeDefaults(suiteName: suiteName, clearsDomain: false)

        #expect(settings.speedSource == .gps)
        #expect(settings.measurementSystem == .metric)
        #expect(
            verificationDefaults.data(forKey: AppSettingsPersistenceFixtures.settingsKey)
                == AppSettingsPersistenceFixtures.legacySettingsData
        )
    }

    @Test("Returns defaults for corrupt data without mutating the stored blob")
    func returnsDefaultsForCorruptData() async {
        let suiteName = makeSuiteName()
        let setupDefaults = makeDefaults(suiteName: suiteName)
        setupDefaults.set(
            AppSettingsPersistenceFixtures.corruptSettingsData,
            forKey: AppSettingsPersistenceFixtures.settingsKey
        )
        let repository = UserDefaultsAppSettingsRepository(
            userDefaults: makeDefaults(suiteName: suiteName, clearsDomain: false)
        )

        #expect(await repository.load() == AppSettings())
        let verificationDefaults = makeDefaults(suiteName: suiteName, clearsDomain: false)
        #expect(
            verificationDefaults.data(forKey: AppSettingsPersistenceFixtures.settingsKey)
                == AppSettingsPersistenceFixtures.corruptSettingsData
        )
    }

    @Test("Broadcasts the same saved settings to every observer")
    func broadcastsSettingsToEveryObserver() async {
        let repository = UserDefaultsAppSettingsRepository(userDefaults: makeDefaults())
        let firstStream = await repository.observe()
        let secondStream = await repository.observe()
        var firstIterator = firstStream.makeAsyncIterator()
        var secondIterator = secondStream.makeAsyncIterator()
        #expect(await firstIterator.next() == AppSettings())
        #expect(await secondIterator.next() == AppSettings())
        let expected = AppSettings(measurementSystem: .metric)

        await repository.save(expected)

        #expect(await firstIterator.next() == expected)
        #expect(await secondIterator.next() == expected)
    }

    @Test("A delayed observer receives only the latest pending settings")
    func delayedObserverReceivesLatestPendingSettings() async {
        let repository = UserDefaultsAppSettingsRepository(userDefaults: makeDefaults())
        let stream = await repository.observe()
        await repository.save(AppSettings(measurementSystem: .metric))
        let expected = AppSettings(measurementSystem: .imperial)
        await repository.save(expected)
        var iterator = stream.makeAsyncIterator()

        #expect(await iterator.next() == expected)
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
