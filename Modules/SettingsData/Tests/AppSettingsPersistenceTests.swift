import Foundation
import SettingsDomain
import Testing

@MainActor
@Suite("App settings persistence")
struct AppSettingsPersistenceTests {
    @Test("Returns defaults until settings are saved")
    func returnsDefaults() async throws {
        let fixture = try VINSettingsTestFixture()
        defer { fixture.cleanUp() }
        let repository = fixture.repository
        #expect(await repository.load() == AppSettings().scoped(toVIN: "FENRTEST000000001"))
    }

    @Test("Persists selected dashboard, speed, units, and battery settings")
    func persistsSettings() async throws {
        let fixture = try VINSettingsTestFixture()
        defer { fixture.cleanUp() }
        let repository = fixture.repository
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
            dashboardTemperatureDisplayMode: .inverter,
            dashboardCardConfiguration: cardConfiguration,
            rideNavigation: RideNavigationSettings(
                avoidsTolls: true,
                avoidsHighways: true,
                preferredMapStyle: .satellite,
                mapOrientation: .northUp,
                miniMapPosition: MiniMapPosition(horizontalFraction: 0.28, verticalFraction: 0.73),
                miniMapScale: MiniMapScale(1.3),
                miniMapLayoutOrientation: .landscape,
                showsGuidanceInFocus: true,
                showsCompassRing: true,
                showsRoadsInFocus: true,
                lineAppearances: RideNavigationLineAppearances(
                    pendingRoute: .init(
                        color: .init(red: 0.1, green: 0.2, blue: 0.3),
                        thickness: .thick
                    )
                )
            ),
            liveActivities: .init(isEnabled: false, showsRiding: false, chargingDetailLevel: .summary),
            measurementSystem: .imperial,
            batteryPackCapacity: .sixPointEightKilowattHours
        ).scoped(toVIN: "FENRTEST000000001")

        await repository.save(expected)

        let reloadedRepository = fixture.reopen()
        #expect(await reloadedRepository.load() == expected)
    }

    @Test("Persists power mode names independently by bike and map")
    func persistsPowerModeNames() async throws {
        let fixture = try VINSettingsTestFixture()
        defer { fixture.cleanUp() }
        let repository = fixture.repository
        var settings = await repository.load()
        try settings.setPowerModeName(
            try PowerModeName("ECO"),
            forVIN: "FENRTEST000000001",
            mapIndex: 0
        )
        await repository.save(settings)
        await fixture.profiles.saveProfile(.init(vin: "FENRTEST000000002"))
        settings = await repository.load()
        try settings.setPowerModeName(
            try PowerModeName("Enduro"),
            forVIN: "FENRTEST000000002",
            mapIndex: 1
        )

        await repository.save(settings)

        let reloaded = await fixture.reopen().load()
        #expect(reloaded.powerModeName(forVIN: "FENRTEST000000001", mapIndex: 0) == nil)
        #expect(reloaded.powerModeName(forVIN: "FENRTEST000000002", mapIndex: 1)?.value == "Enduro")
        await fixture.profiles.saveProfile(.init(vin: "FENRTEST000000001"))
        let first = await fixture.reopen().load()
        #expect(first.powerModeName(forVIN: "FENRTEST000000001", mapIndex: 0)?.value == "ECO")
        #expect(first.powerModeName(forVIN: "FENRTEST000000002", mapIndex: 1) == nil)
    }

    @Test("Persists Bike Lock security independently by bike")
    func persistsBikeLockSettingsByBike() async throws {
        let fixture = try VINSettingsTestFixture()
        defer { fixture.cleanUp() }
        let repository = fixture.repository
        var settings = await repository.load()
        settings.setBikeLockSettings(
            .init(securityMode: .pinAndFaceID),
            forVIN: "FENRTEST000000001"
        )

        await repository.save(settings)

        let reloaded = await fixture.reopen().load()
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
    func skipsDuplicateSettingsNotifications() async throws {
        let fixture = try VINSettingsTestFixture()
        defer { fixture.cleanUp() }
        let repository = fixture.repository
        let stream = await repository.observe()
        var iterator = stream.makeAsyncIterator()
        #expect(await iterator.next() == AppSettings().scoped(toVIN: "FENRTEST000000001"))
        let metric = AppSettings(measurementSystem: .metric).scoped(toVIN: "FENRTEST000000001")
        let imperial = AppSettings(measurementSystem: .imperial).scoped(toVIN: "FENRTEST000000001")

        await repository.save(metric)
        #expect(await iterator.next() == metric)
        await repository.save(metric)
        await repository.save(imperial)

        #expect(await iterator.next() == imperial)
    }

    @Test("Loads the legacy blob from the stable settings key without rewriting it")
    func loadsLegacyBlobFromStableKey() async throws {
        let fixture = try VINSettingsTestFixture()
        defer { fixture.cleanUp() }
        let setupDefaults = try #require(UserDefaults(suiteName: fixture.suite))
        setupDefaults.set(
            AppSettingsPersistenceFixtures.legacySettingsData,
            forKey: AppSettingsPersistenceFixtures.settingsKey
        )
        let repository = fixture.repository

        let settings = await repository.load()
        let verificationDefaults = try #require(UserDefaults(suiteName: fixture.suite))

        #expect(settings.speedSource == .gps)
        #expect(settings.measurementSystem == .metric)
        #expect(
            verificationDefaults.data(forKey: AppSettingsPersistenceFixtures.settingsKey)
                == AppSettingsPersistenceFixtures.legacySettingsData
        )
    }

    @Test("Returns defaults for corrupt data without mutating the stored blob")
    func returnsDefaultsForCorruptData() async throws {
        let fixture = try VINSettingsTestFixture()
        defer { fixture.cleanUp() }
        let setupDefaults = try #require(UserDefaults(suiteName: fixture.suite))
        setupDefaults.set(
            AppSettingsPersistenceFixtures.corruptSettingsData,
            forKey: AppSettingsPersistenceFixtures.settingsKey
        )
        let repository = fixture.repository

        #expect(await repository.load() == AppSettings().scoped(toVIN: "FENRTEST000000001"))
        let verificationDefaults = try #require(UserDefaults(suiteName: fixture.suite))
        #expect(
            verificationDefaults.data(forKey: AppSettingsPersistenceFixtures.settingsKey)
                == AppSettingsPersistenceFixtures.corruptSettingsData
        )
    }

    @Test("Broadcasts the same saved settings to every observer")
    func broadcastsSettingsToEveryObserver() async throws {
        let fixture = try VINSettingsTestFixture()
        defer { fixture.cleanUp() }
        let repository = fixture.repository
        let firstStream = await repository.observe()
        let secondStream = await repository.observe()
        var firstIterator = firstStream.makeAsyncIterator()
        var secondIterator = secondStream.makeAsyncIterator()
        #expect(await firstIterator.next() == AppSettings().scoped(toVIN: "FENRTEST000000001"))
        #expect(await secondIterator.next() == AppSettings().scoped(toVIN: "FENRTEST000000001"))
        let expected = AppSettings(measurementSystem: .metric).scoped(toVIN: "FENRTEST000000001")

        await repository.save(expected)

        #expect(await firstIterator.next() == expected)
        #expect(await secondIterator.next() == expected)
    }

    @Test("A delayed observer receives only the latest pending settings")
    func delayedObserverReceivesLatestPendingSettings() async throws {
        let fixture = try VINSettingsTestFixture()
        defer { fixture.cleanUp() }
        let repository = fixture.repository
        let stream = await repository.observe()
        await repository.save(AppSettings(measurementSystem: .metric).scoped(toVIN: "FENRTEST000000001"))
        let expected = AppSettings(measurementSystem: .imperial).scoped(toVIN: "FENRTEST000000001")
        await repository.save(expected)
        var iterator = stream.makeAsyncIterator()

        #expect(await iterator.next() == expected)
    }

}
