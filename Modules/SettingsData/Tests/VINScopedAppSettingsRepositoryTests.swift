import BikeDomain
import Foundation
import SettingsDomain
import Testing
import TestSupport

@MainActor
@Suite("VIN-scoped settings")
struct VINScopedAppSettingsRepositoryTests {
    @Test("Every configuration belongs to a VIN and another bike starts with defaults")
    func switchesAndRestoresSettings() async throws {
        let fixture = try VINSettingsTestFixture()
        defer { fixture.cleanUp() }
        var first = await fixture.repository.load()
        #expect(first.vin == "FENRTEST000000001")
        first.measurementSystem = .imperial
        first.speedSource = .gps
        first.dashboardTemperatureDisplayMode = .both
        first.rideNavigation.avoidsTolls = true
        first.dashboardCardConfiguration.setSectionVisibility(false, id: .efficiency)
        await fixture.repository.save(first)
        await fixture.profiles.saveProfile(.init(vin: "FENRTEST000000002"))
        var second = await fixture.repository.load()
        #expect(second == AppSettings().scoped(toVIN: "FENRTEST000000002"))
        second.measurementSystem = .metric
        await fixture.repository.save(second)
        var stale = first
        stale.measurementSystem = .system
        await fixture.repository.save(stale)
        #expect(await fixture.repository.load() == second)
        await fixture.profiles.saveProfile(.init(vin: "FENRTEST000000001"))
        #expect(await fixture.reopen().load() == first)
        await fixture.profiles.saveProfile(.init(vin: "FENRTEST000000002"))
        #expect(await fixture.reopen().load() == second)
    }

    @Test("Migration assigns legacy general settings only to the selected bike and keeps existing VIN values")
    func migratesLegacySettings() async throws {
        var legacy = AppSettings(measurementSystem: .imperial)
        legacy.setBatteryPackCapacity(.sixPointEightKilowattHours, forVIN: "FENRTEST000000002")
        try legacy.setPowerModeName(try PowerModeName("Trail"), forVIN: "FENRTEST000000002", mapIndex: 1)
        legacy.setBikeLockSettings(.init(securityMode: .pinAndFaceID), forVIN: "FENRTEST000000002")
        let fixture = try VINSettingsTestFixture(legacy: legacy)
        defer { fixture.cleanUp() }
        #expect(await fixture.repository.load() == legacy.scoped(toVIN: "FENRTEST000000001"))
        await fixture.profiles.saveProfile(.init(vin: "FENRTEST000000002"))
        let second = await fixture.repository.load()
        #expect(second.measurementSystem == .system)
        #expect(second.batteryPackCapacity(forVIN: second.vin) == .sixPointEightKilowattHours)
        #expect(second.powerModeName(forVIN: second.vin, mapIndex: 1)?.value == "Trail")
        #expect(second.bikeLockSettings(forVIN: second.vin).securityMode == .pinAndFaceID)
        let data = try #require(UserDefaults(suiteName: fixture.suite)?.data(forKey: "fenr.bike.settings.v1"))
        let records = try JSONDecoder().decode([String: AppSettings].self, from: data)
        #expect(records.allSatisfy { $0.key == $0.value.vin })
        #expect(records.count == 2)
    }

    @Test("Unselected legacy settings are not inherited by a newly paired bike")
    func doesNotMigrateUnownedSettingsToNewBike() async throws {
        let fixture = try VINSettingsTestFixture(vin: nil, legacy: .init(measurementSystem: .imperial))
        defer { fixture.cleanUp() }
        #expect(await fixture.repository.load() == AppSettings())
        await fixture.profiles.saveProfile(.init(vin: "FENRTEST000000002"))
        #expect(await fixture.repository.load() == AppSettings().scoped(toVIN: "FENRTEST000000002"))
    }

    @Test("Observers switch context, clear on unpairing, and can restart without stale settings")
    func observesProfileChanges() async throws {
        let fixture = try VINSettingsTestFixture()
        defer { fixture.cleanUp() }
        let recorder = SettingsSnapshotRecorder()
        let repository = fixture.repository
        let observation = Task {
            for await value in await repository.observe() {
                guard !Task.isCancelled else { return }
                recorder.append(value)
            }
        }
        defer { observation.cancel() }
        #expect(await waitUntil { recorder.values.last?.vin == "FENRTEST000000001" })
        await fixture.profiles.saveProfile(.init(vin: "FENRTEST000000002"))
        #expect(await waitUntil { recorder.values.last?.vin == "FENRTEST000000002" })
        await fixture.profiles.clearProfile()
        #expect(await waitUntil { recorder.values.last == AppSettings() })
        observation.cancel()
        await observation.value
        let restarted = Task {
            for await value in await repository.observe() {
                guard !Task.isCancelled else { return }
                recorder.append(value)
            }
        }
        defer { restarted.cancel() }
        await fixture.profiles.saveProfile(.init(vin: "FENRTEST000000001"))
        #expect(await waitUntil { recorder.values.last?.vin == "FENRTEST000000001" })
        restarted.cancel()
        await restarted.value
    }

    @Test("Missing or invalid VINs cannot save settings and valid identities are normalized")
    func validatesOwnership() async throws {
        let fixture = try VINSettingsTestFixture(vin: "invalid")
        defer { fixture.cleanUp() }
        await fixture.repository.save(.init(measurementSystem: .imperial))
        #expect(await fixture.repository.load() == AppSettings())
        await fixture.profiles.saveProfile(.init(vin: "fenrtest000000001"))
        var settings = await fixture.repository.load()
        #expect(settings.vin == "FENRTEST000000001")
        settings.measurementSystem = .metric
        await fixture.repository.save(settings)
        #expect(await fixture.reopen().load() == settings)
    }

    @Test("A malformed VIN store is preserved instead of overwritten by defaults")
    func preservesMalformedStore() async throws {
        let fixture = try VINSettingsTestFixture()
        defer { fixture.cleanUp() }
        let defaults = try #require(UserDefaults(suiteName: fixture.suite))
        let malformed = Data("invalid".utf8)
        defaults.set(malformed, forKey: "fenr.bike.settings.v1")
        var settings = await fixture.repository.load()
        settings.measurementSystem = .imperial
        await fixture.repository.save(settings)
        #expect(defaults.data(forKey: "fenr.bike.settings.v1") == malformed)
    }
}
