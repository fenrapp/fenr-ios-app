import Foundation
import SettingsDomain
import Testing

@MainActor
@Suite("App settings persistence")
struct AppSettingsPersistenceTests {
    @Test("Retired thickness loads and permits unrelated saves without losing settings", arguments: [false, true])
    func migratesRetiredThickness(scoped: Bool) async throws {
        let fixture = try VINSettingsTestFixture()
        defer { fixture.cleanUp() }
        let defaults = try #require(UserDefaults(suiteName: fixture.suite))
        let key = scoped
            ? AppSettingsPersistenceFixtures.scopedSettingsKey : AppSettingsPersistenceFixtures.settingsKey
        let original = AppSettingsPersistenceFixtures.settingsWithThickness("extraThick", scoped: scoped)
        defaults.set(original, forKey: key)
        var expected = AppSettings(
            speedSource: .gps, dashboardProgressBarMode: .speed,
            dashboardProgressBarThickness: .thick, measurementSystem: .imperial
        ).scoped(toVIN: "FENRTEST000000001")

        #expect(await fixture.repository.load() == expected)
        _ = try await fixture.repository.update(
            expectedVIN: "FENRTEST000000001", change: .dashboardDeviceBatteryDisplayMode(.hidden)
        )
        expected.dashboardDeviceBatteryDisplayMode = .hidden
        #expect(await fixture.reopen().load() == expected)
        let saved = try #require(defaults.data(forKey: AppSettingsPersistenceFixtures.scopedSettingsKey))
        let records = try #require(JSONSerialization.jsonObject(with: saved) as? [String: [String: Any]])
        #expect(records["FENRTEST000000001"]?["dashboardProgressBarThickness"] as? String == "thick")
        if !scoped { #expect(defaults.data(forKey: key) == original) }
    }

    @Test("Unknown thickness rejects writes and preserves the original store", arguments: [false, true])
    func preservesUnknownThickness(scoped: Bool) async throws {
        let fixture = try VINSettingsTestFixture()
        defer { fixture.cleanUp() }
        let defaults = try #require(UserDefaults(suiteName: fixture.suite))
        let key = scoped
            ? AppSettingsPersistenceFixtures.scopedSettingsKey : AppSettingsPersistenceFixtures.settingsKey
        let original = AppSettingsPersistenceFixtures.settingsWithThickness("unsupported", scoped: scoped)
        defaults.set(original, forKey: key)

        _ = await fixture.repository.load()
        await #expect(throws: AppSettingsUpdateError.unreadableStore) {
            try await fixture.repository.update(
                expectedVIN: "FENRTEST000000001", change: .measurementSystem(.metric)
            )
        }
        #expect(defaults.data(forKey: key) == original)
        if !scoped {
            #expect(defaults.object(forKey: AppSettingsPersistenceFixtures.scopedSettingsKey) == nil)
        }
    }

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
            .bikeLock, .range, .navigation, .currentTrip, .efficiency, .systemHealth, .rideDynamics
        ])
        cardConfiguration.setSectionVisibility(false, id: .efficiency)
        let expected = AppSettings(
            speedSource: .hybrid,
            dashboardProgressBarMode: .speed, dashboardProgressBarThickness: .thick,
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
            batteryPackCapacitiesByVIN: ["FENRTEST000000001": .sixPointEightKilowattHours]
        ).scoped(toVIN: "FENRTEST000000001")

        let changes: [AppSettingsChange] = [
            .speedSource(.hybrid), .dashboardProgressBarMode(.speed), .dashboardProgressBarThickness(.thick),
            .dashboardBatteryIndicatorMode(.estimatedRange), .dashboardDeviceBatteryDisplayMode(.hidden),
            .dashboardTemperatureDisplayMode(.inverter), .measurementSystem(.imperial),
            .batteryPackCapacity(.sixPointEightKilowattHours),
            .dashboard(.sectionOrder([.range, .navigation, .currentTrip, .efficiency, .systemHealth, .rideDynamics])),
            .dashboard(.sectionVisibility(id: .efficiency, isVisible: false)),
            .navigation(.avoidsTolls(true)), .navigation(.avoidsHighways(true)),
            .navigation(.preferredMapStyle(.satellite)), .navigation(.mapOrientation(.northUp)),
            .navigation(.miniMapPosition(.init(horizontalFraction: 0.28, verticalFraction: 0.73))),
            .navigation(.miniMapScale(.init(1.3))), .navigation(.miniMapLayoutOrientation(.landscape)),
            .navigation(.showsGuidanceInFocus(true)), .navigation(.showsCompassRing(true)),
            .navigation(.showsRoadsInFocus(true)),
            .navigation(.lineColor(group: .pendingRoute, color: .init(red: 0.1, green: 0.2, blue: 0.3))),
            .navigation(.lineThickness(group: .pendingRoute, thickness: .thick)),
            .liveActivities(.isEnabled(false)), .liveActivities(.showsRiding(false)),
            .liveActivities(.chargingDetailLevel(.summary))
        ]
        for change in changes {
            _ = try await repository.update(expectedVIN: "FENRTEST000000001", change: change)
        }

        let reloadedRepository = fixture.reopen()
        #expect(await reloadedRepository.load() == expected)
    }

    @Test("Persists power mode names independently by bike and map")
    func persistsPowerModeNames() async throws {
        let fixture = try VINSettingsTestFixture()
        defer { fixture.cleanUp() }
        let repository = fixture.repository
        _ = try await repository.update(expectedVIN: "FENRTEST000000001",
                                        change: .powerModeName(mapIndex: 0, name: try PowerModeName("ECO")))
        await fixture.profiles.saveProfile(.init(vin: "FENRTEST000000002"))

        _ = try await repository.update(expectedVIN: "FENRTEST000000002",
                                        change: .powerModeName(mapIndex: 1, name: try PowerModeName("Enduro")))

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

        _ = try await repository.update(expectedVIN: "FENRTEST000000001", change: .bikeLockSecurity(.pinAndFaceID))

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
        #expect(await iterator.next()?.settings == AppSettings().scoped(toVIN: "FENRTEST000000001"))
        let metric = AppSettings(measurementSystem: .metric).scoped(toVIN: "FENRTEST000000001")
        let imperial = AppSettings(measurementSystem: .imperial).scoped(toVIN: "FENRTEST000000001")

        _ = try await repository.update(expectedVIN: "FENRTEST000000001", change: .measurementSystem(.metric))
        #expect(await iterator.next()?.settings == metric)
        _ = try await repository.update(expectedVIN: "FENRTEST000000001", change: .measurementSystem(.metric))
        _ = try await repository.update(expectedVIN: "FENRTEST000000001", change: .measurementSystem(.imperial))

        #expect(await iterator.next()?.settings == imperial)
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
        #expect(await firstIterator.next()?.settings == AppSettings().scoped(toVIN: "FENRTEST000000001"))
        #expect(await secondIterator.next()?.settings == AppSettings().scoped(toVIN: "FENRTEST000000001"))
        let expected = AppSettings(measurementSystem: .metric).scoped(toVIN: "FENRTEST000000001")

        _ = try await repository.update(
            expectedVIN: "FENRTEST000000001", change: .measurementSystem(expected.measurementSystem)
        )

        #expect(await firstIterator.next()?.settings == expected)
        #expect(await secondIterator.next()?.settings == expected)
    }

    @Test("A delayed observer receives only the latest pending settings")
    func delayedObserverReceivesLatestPendingSettings() async throws {
        let fixture = try VINSettingsTestFixture()
        defer { fixture.cleanUp() }
        let repository = fixture.repository
        let stream = await repository.observe()
        _ = try await repository.update(expectedVIN: "FENRTEST000000001", change: .measurementSystem(.metric))
        let expected = AppSettings(measurementSystem: .imperial).scoped(toVIN: "FENRTEST000000001")
        _ = try await repository.update(
            expectedVIN: "FENRTEST000000001", change: .measurementSystem(expected.measurementSystem)
        )
        var iterator = stream.makeAsyncIterator()

        #expect(await iterator.next()?.settings == expected)
    }

}
