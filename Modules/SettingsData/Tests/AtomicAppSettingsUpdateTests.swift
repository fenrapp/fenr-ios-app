import Foundation
import SettingsDomain
import Testing
import TestSupport

@MainActor
@Suite("Atomic settings updates")
struct AtomicAppSettingsUpdateTests {
    private let vin = "FENRTEST000000001"

    @Test("Concurrent commands preserve independent values within the same settings groups")
    func preservesConcurrentChanges() async throws {
        let fixture = try VINSettingsTestFixture()
        defer { fixture.cleanUp() }
        let repository = fixture.repository
        let changes: [AppSettingsChange] = [
            .measurementSystem(.imperial), .dashboardDeviceBatteryDisplayMode(.textOnly),
            .navigation(.avoidsTolls(true)), .navigation(.mapOrientation(.northUp)),
            .navigation(.lineColor(group: .pendingRoute, color: .init(red: 0.2, green: 0.3, blue: 0.4))),
            .navigation(.lineThickness(group: .pendingRoute, thickness: .thick)),
            .liveActivities(.showsRiding(false)), .liveActivities(.showsCharging(false)),
            .dashboard(.sectionVisibility(id: .range, isVisible: false)),
            .dashboard(.pageVisibility(sectionID: .currentTrip, id: .rideStatistics, isVisible: false))
        ]
        try await withThrowingTaskGroup(of: Void.self) { group in
            for change in changes {
                group.addTask { _ = try await repository.update(expectedVIN: vin, change: change) }
            }
            try await group.waitForAll()
        }
        let settings = await fixture.reopen().load()
        #expect(settings.measurementSystem == .imperial)
        #expect(settings.dashboardDeviceBatteryDisplayMode == .textOnly)
        #expect(settings.rideNavigation.avoidsTolls)
        #expect(settings.rideNavigation.mapOrientation == .northUp)
        #expect(settings.rideNavigation.lineAppearances.pendingRoute.color == .init(red: 0.2, green: 0.3, blue: 0.4))
        #expect(settings.rideNavigation.lineAppearances.pendingRoute.thickness == .thick)
        #expect(!settings.liveActivities.showsRiding && !settings.liveActivities.showsCharging)
        #expect(!settings.dashboardCardConfiguration.section(id: .range).isVisible)
        #expect(settings.dashboardCardConfiguration.section(id: .currentTrip).pages.filter(\.isVisible).count == 1)
    }

    @Test("Concurrent names validate uniqueness against the latest persisted values")
    func validatesConcurrentNames() async throws {
        let fixture = try VINSettingsTestFixture()
        defer { fixture.cleanUp() }
        let repository = fixture.repository
        let name = try PowerModeName("Trail")
        let successes = await withTaskGroup(of: Bool.self) { group in
            for mapIndex in [0, 1] {
                group.addTask {
                    do {
                        _ = try await repository.update(
                            expectedVIN: vin, change: .powerModeName(mapIndex: mapIndex, name: name)
                        )
                        return true
                    } catch {
                        #expect(error as? AppSettingsUpdateError == .duplicatePowerModeName)
                        return false
                    }
                }
            }
            var count = 0
            for await succeeded in group where succeeded { count += 1 }
            return count
        }
        #expect(successes == 1)
        #expect(await repository.load().powerModeNames(forVIN: vin).count == 1)
    }

    @Test("No-op updates preserve revisions and do not notify observers")
    func noOpDoesNotPublish() async throws {
        let fixture = try VINSettingsTestFixture()
        defer { fixture.cleanUp() }
        let repository = fixture.repository
        var iterator = await repository.observe().makeAsyncIterator()
        let initial = try #require(await iterator.next())
        let hidden = try await repository.update(
            expectedVIN: vin,
            change: .dashboard(.pageVisibility(sectionID: .currentTrip, id: .rideStatistics, isVisible: false))
        )
        #expect(await iterator.next() == hidden.snapshot)
        let duplicate = try await repository.update(
            expectedVIN: vin,
            change: .dashboard(.pageVisibility(sectionID: .currentTrip, id: .rideStatistics, isVisible: false))
        )
        #expect(duplicate == .unchanged(hidden.snapshot))
        let changed = try await repository.update(expectedVIN: vin, change: .measurementSystem(.imperial))
        #expect(changed.snapshot.revision == initial.revision + 2)
        #expect(await iterator.next() == changed.snapshot)
    }

    @Test("A vehicle change while the command waits rejects the old identity")
    func rejectsOldIdentityAfterSuspension() async throws {
        let fixture = try VINSettingsTestFixture()
        defer { fixture.cleanUp() }
        await fixture.profiles.pauseNextLoad()
        async let error = attemptSuspendedUpdate(repository: fixture.repository)
        #expect(await waitUntil { await fixture.profiles.hasPendingLoad() })
        await fixture.profiles.saveProfile(.init(vin: "FENRTEST000000002"))
        await fixture.profiles.resumeLoad()
        let actualError = await error
        #expect(actualError == .vehicleChanged)
        #expect(await fixture.repository.load().measurementSystem == .system)
    }

    @Test("An unreadable store preserves the last confirmed values and the corrupt bytes")
    func retainsKnownSettingsAfterReadFailure() async throws {
        let fixture = try VINSettingsTestFixture()
        defer { fixture.cleanUp() }
        let result = try await fixture.repository.update(expectedVIN: vin, change: .measurementSystem(.imperial))
        let defaults = try #require(UserDefaults(suiteName: fixture.suite))
        let corrupt = Data("invalid".utf8)
        defaults.set(corrupt, forKey: "fenr.bike.settings.v1")
        #expect(await fixture.repository.load() == result.snapshot.settings)
        var iterator = await fixture.repository.observe().makeAsyncIterator()
        #expect(await iterator.next() == result.snapshot)
        await #expect(throws: AppSettingsUpdateError.unreadableStore) {
            try await fixture.repository.update(expectedVIN: vin, change: .measurementSystem(.metric))
        }
        #expect(defaults.data(forKey: "fenr.bike.settings.v1") == corrupt)
    }

    @Test("A malformed legacy store cannot be migrated into empty records")
    func preservesMalformedLegacyStore() async throws {
        let fixture = try VINSettingsTestFixture()
        defer { fixture.cleanUp() }
        let defaults = try #require(UserDefaults(suiteName: fixture.suite))
        let corrupt = Data("invalid".utf8)
        defaults.set(corrupt, forKey: "fenr.app.settings")
        _ = await fixture.repository.load()
        await #expect(throws: AppSettingsUpdateError.unreadableStore) {
            try await fixture.repository.update(expectedVIN: vin, change: .measurementSystem(.metric))
        }
        #expect(defaults.object(forKey: "fenr.bike.settings.v1") == nil)
        #expect(defaults.data(forKey: "fenr.app.settings") == corrupt)
    }

    @Test("An existing store with the wrong value type is preserved", arguments: [
        "fenr.app.settings", "fenr.bike.settings.v1"
    ])
    func preservesWrongStoreType(key: String) async throws {
        let fixture = try VINSettingsTestFixture()
        defer { fixture.cleanUp() }
        let defaults = try #require(UserDefaults(suiteName: fixture.suite))
        defaults.set("invalid", forKey: key)
        _ = await fixture.repository.load()
        await #expect(throws: AppSettingsUpdateError.unreadableStore) {
            try await fixture.repository.update(expectedVIN: vin, change: .measurementSystem(.metric))
        }
        #expect(defaults.string(forKey: key) == "invalid")
        if key == "fenr.app.settings" { #expect(defaults.object(forKey: "fenr.bike.settings.v1") == nil) }
    }

    @Test("Profile replay and observer restart preserve increasing runtime revisions")
    func profileRevisionsSurviveObservationRestart() async throws {
        let fixture = try VINSettingsTestFixture()
        defer { fixture.cleanUp() }
        let first = try await fixture.repository.update(expectedVIN: vin, change: .measurementSystem(.imperial))
        await fixture.profiles.saveProfile(.init(vin: "FENRTEST000000002"))
        var iterator = await fixture.repository.observe().makeAsyncIterator()
        let second = try #require(await iterator.next())
        #expect(second.revision > first.snapshot.revision)
        #expect(second.settings.vin == "FENRTEST000000002")
        await fixture.profiles.clearProfile()
        _ = await fixture.repository.load()
        let unpaired = try #require(await iterator.next())
        #expect(unpaired.revision > second.revision)
        #expect(unpaired.settings.vin == nil)
    }

    private func attemptSuspendedUpdate(repository: any AppSettingsRepository) async -> AppSettingsUpdateError? {
        do {
            _ = try await repository.update(expectedVIN: vin, change: .measurementSystem(.imperial))
            return nil
        } catch {
            return error as? AppSettingsUpdateError
        }
    }
}
