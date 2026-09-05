import Foundation
import MaintenanceLog
import Testing
import TestSupport

@MainActor
@Suite("Production experience recovery")
struct AppExperienceRecoveryTests {
    @Test("Every storage failure propagates before runtime composition and preserves existing records",
          arguments: ["rides", "maintenance", "calibration"])
    func storageFailurePreservesRecords(failingStore: String) async throws {
        let fixture = DemoExperienceTestFixture()
        let template = try await fixture.factory.make(identity: fixture.identity)
        let rides = try fixture.makeRides()
        let maintenance = try fixture.makeMaintenance()
        let originalTrips = await rides.loadCompletedTrips(vin: fixture.identity.vin)
        let originalEntries = await maintenance.loadEntries(vin: fixture.identity.vin)
        let recorder = AppRecoveryRecorder()
        recorder.failingStore = failingStore
        let storageFactory = ProductionAppStorageFactory(
            makeRides: { try recorder.open("rides"); return rides },
            makeMaintenance: { try recorder.open("maintenance"); return maintenance },
            makeCalibration: {
                try recorder.open("calibration")
                Issue.record("Calibration must fail before opening a production store")
                throw AppExperienceFailure.storage
            }
        )

        #expect(throws: AppExperienceFailure.storage) {
            try ProductionAppDependencyContainerFactory.makeDefault(
                maintenanceReminderScheduler: NoOpMaintenanceReminderScheduler(),
                storageFactory: storageFactory
            )
        }
        let stages = ["rides", "maintenance", "calibration"]
        let failedIndex = try #require(stages.firstIndex(of: failingStore))
        #expect(recorder.openedStores == Array(stages.prefix(failedIndex + 1)))
        #expect(await rides.loadCompletedTrips(vin: fixture.identity.vin).map(\.id) == originalTrips.map(\.id))
        #expect(await maintenance.loadEntries(vin: fixture.identity.vin).map(\.id) == originalEntries.map(\.id))
        await template.close()
        try await template.discard()
    }

    @Test("A production startup failure has distinct recovery and repeated retry builds once")
    func realFailureRetriesOnce() async throws {
        let fixture = DemoExperienceTestFixture()
        let template = try await fixture.factory.make(identity: fixture.identity)
        let suite = "fenr.tests.recovery.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("retained", forKey: "test.preference")
        let selection = makeSelection(defaults: defaults)
        let recorder = AppRecoveryRecorder()
        let real = AppExperience(id: UUID(), root: template.root, demoViewModel: nil, close: {}, discard: {})
        let controller = AppExperienceController(
            selectionStore: selection,
            makeReal: { try recorder.buildReal(); return real },
            makeDemo: { _ in Issue.record("Unexpected demo factory"); return template },
            discardDemo: { _ in Issue.record("Unexpected deletion") }
        )

        controller.restore()
        controller.restore()
        #expect(await waitUntil { controller.failure == .storage && !controller.isBusy })
        #expect(controller.experience == nil)
        #expect(recorder.realAttempts == 1)
        recorder.failsRealExperience = false
        controller.restore()
        controller.restore()
        #expect(await waitUntil { controller.experience?.id == real.id && !controller.isBusy })
        #expect(controller.failure == nil)
        #expect(recorder.realAttempts == 2)
        #expect(defaults.string(forKey: "test.preference") == "retained")
        #expect(try selection.load() == nil)
        await template.close()
        try await template.discard()
    }

    @Test("Storage failure after leaving demo retries real setup without deleting saved demo")
    func storageFailureAfterDemoExit() async throws {
        let fixture = DemoExperienceTestFixture()
        let template = try await fixture.factory.make(identity: fixture.identity)
        let suite = "fenr.tests.recovery.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let selection = makeSelection(defaults: defaults)
        try selection.save(fixture.identity)
        let recorder = AppRecoveryRecorder()
        let real = AppExperience(id: UUID(), root: template.root, demoViewModel: nil, close: {}, discard: {})
        let controller = AppExperienceController(
            selectionStore: selection,
            makeReal: { try recorder.buildReal(); return real },
            makeDemo: { _ in template },
            discardDemo: { _ in Issue.record("Unexpected deletion") }
        )
        controller.restore()
        #expect(await waitUntil { controller.experience?.id == template.id && !controller.isBusy })
        controller.changeBike()
        #expect(await waitUntil { controller.failure == .storage && !controller.isBusy })
        #expect(controller.experience == nil)
        #expect(try selection.load() == nil)
        #expect(try selection.loadSavedIdentity() == fixture.identity)
        recorder.failsRealExperience = false
        controller.restore()
        #expect(await waitUntil { controller.experience?.id == real.id && !controller.isBusy })
        #expect(recorder.realAttempts == 2)
        #expect(try selection.loadSavedIdentity() == fixture.identity)
        try await template.discard()
    }
}
