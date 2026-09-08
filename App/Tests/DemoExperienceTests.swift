import Foundation
import Testing
import TestSupport

@MainActor
@Suite("Demo experience integration")
struct DemoExperienceTests {
    @Test("Seeds once, keeps deletions and restores the same selected scenario")
    func seedsOnceAndRestores() async throws {
        let fixture = DemoExperienceTestFixture()
        let experience = try await fixture.factory.make(identity: fixture.identity)
        await experience.root.lifecycleController.start()
        #expect(experience.root.setupFlow.configuredVIN == fixture.identity.vin)
        let model = try #require(experience.demoViewModel)
        model.select(id: "charging")
        #expect(await waitUntil { model.viewState.selectedID == "charging" })
        let rides = try fixture.makeRides()
        let maintenance = try fixture.makeMaintenance()
        let trips = try await rides.loadCompletedTrips(vin: fixture.identity.vin)
        let entries = try await maintenance.loadEntries(vin: fixture.identity.vin)
        #expect(trips.count == 3)
        #expect(entries.count == 2)
        let trip = try #require(trips.first)
        let entry = try #require(entries.first)
        #expect(await rides.deleteCompletedTrip(id: trip.id, vin: fixture.identity.vin))
        #expect(await maintenance.deleteEntry(id: entry.id, vin: fixture.identity.vin))
        await experience.close()
        let reopened = try await fixture.factory.make(identity: fixture.identity)
        #expect(reopened.demoViewModel?.viewState.selectedID == "charging")
        #expect(try await rides.loadCompletedTrips(vin: fixture.identity.vin).count == 2)
        #expect(try await maintenance.loadEntries(vin: fixture.identity.vin).count == 1)
        await reopened.close()
        try await reopened.discard()
        #expect(!FileManager.default.fileExists(
            atPath: fixture.directory.appendingPathComponent(fixture.identity.id.uuidString).path
        ))
    }

    @Test("Rapid scenario selections settle on the most recent intent")
    func latestScenarioWins() async throws {
        let fixture = DemoExperienceTestFixture()
        let experience = try await fixture.factory.make(identity: fixture.identity)
        await experience.root.lifecycleController.start()
        let model = try #require(experience.demoViewModel)
        model.select(id: "riding")
        model.select(id: "charging")
        model.select(id: "cellAnomaly")
        #expect(await waitUntil { model.viewState.selectedID == "cellAnomaly" })
        await experience.close()
        try await experience.discard()
    }
}
