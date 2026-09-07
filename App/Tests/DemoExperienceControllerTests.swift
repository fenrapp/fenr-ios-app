import Foundation
import MaintenanceLog
import Testing
import TestSupport

@MainActor
@Suite("Demo experience transitions")
struct DemoExperienceControllerTests {
    @Test("An unreadable active selection can return to setup without losing the saved demo")
    func invalidSelectionCanReturnToSetup() async throws {
        let fixture = DemoExperienceTestFixture()
        let template = try await fixture.factory.make(identity: fixture.identity)
        let suite = "fenr.tests.selection.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let selection = DemoSelectionStore(
            defaults: defaults, encoder: JSONEncoder(), decoder: JSONDecoder(),
            makeID: UUID.init, makeDigits: { "987654321" }, now: Date.init
        )
        try selection.save(fixture.identity)
        defaults.set(Data("invalid".utf8), forKey: "com.fenr.experience.demo.v1")
        let real = AppExperience(id: UUID(), root: template.root, demoViewModel: nil, close: {}, discard: {})
        let controller = AppExperienceController(
            selectionStore: selection, makeReal: { real },
            makeDemo: { _ in template }, discardDemo: { _ in Issue.record("Unexpected demo deletion") }
        )
        controller.restore()
        #expect(await waitUntil { controller.hasError && !controller.isBusy })
        controller.changeBike()
        #expect(await waitUntil { controller.experience?.id == real.id && !controller.isBusy })
        #expect(!controller.hasError)
        #expect(try selection.load() == nil)
        #expect(try selection.loadSavedIdentity() == fixture.identity)
        await template.close()
        try await template.discard()
    }

    @Test("Repeated entry is serialized and a saved demo bypasses the real factory")
    func entryIsSerialized() async throws {
        let fixture = DemoExperienceTestFixture()
        let template = try await fixture.factory.make(identity: fixture.identity)
        let recorder = DemoTransitionRecorder()
        let suite = "fenr.tests.selection.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let selection = DemoSelectionStore(
            defaults: defaults, encoder: JSONEncoder(), decoder: JSONDecoder(),
            makeID: { fixture.identity.id }, makeDigits: { "123456789" }, now: Date.init
        )
        let real = AppExperience(
            id: UUID(), root: template.root, demoViewModel: nil,
            close: { recorder.record("close-real") }, discard: {}
        )
        let controller = AppExperienceController(
            selectionStore: selection,
            makeReal: { recorder.record("build-real"); return real },
            makeDemo: { _ in await recorder.wait(); return template },
            discardDemo: { _ in }
        )
        controller.restore()
        #expect(await waitUntil { controller.experience != nil })
        controller.startDemo()
        controller.startDemo()
        #expect(await waitUntil { recorder.isWaiting })
        #expect(recorder.events == ["build-real", "close-real", "build-demo"])
        #expect(controller.isBusy)
        recorder.resume()
        #expect(await waitUntil { !controller.isBusy })
        #expect(controller.experience?.id == fixture.identity.id)
        #expect(try selection.load()?.id == fixture.identity.id)
        let restored = AppExperienceController(
            selectionStore: selection,
            makeReal: { recorder.record("unexpected-real"); return real },
            makeDemo: { _ in template }, discardDemo: { _ in }
        )
        restored.restore()
        #expect(await waitUntil { restored.experience != nil })
        #expect(!recorder.events.contains("unexpected-real"))
        await template.close()
        try await template.discard()
    }

    @Test("Preparation failure leaves no completed selection and can return to setup")
    func failureIsRecoverable() async throws {
        let fixture = DemoExperienceTestFixture()
        let template = try await fixture.factory.make(identity: fixture.identity)
        let suite = "fenr.tests.selection.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let recorder = DemoTransitionRecorder()
        let selection = DemoSelectionStore(
            defaults: defaults, encoder: JSONEncoder(), decoder: JSONDecoder(),
            makeID: { fixture.identity.id }, makeDigits: { "123456789" }, now: Date.init
        )
        let real = AppExperience(id: UUID(), root: template.root, demoViewModel: nil, close: {}, discard: {})
        let controller = AppExperienceController(
            selectionStore: selection, makeReal: { real },
            makeDemo: { _ in throw DemoPreparationError.seedingFailed },
            discardDemo: { _ in recorder.record("discard-partial") }
        )
        controller.startDemo()
        #expect(await waitUntil { controller.hasError })
        #expect(controller.experience == nil)
        #expect(try selection.load() == nil)
        controller.changeBike()
        #expect(await waitUntil { controller.experience != nil })
        #expect(!controller.hasError)
        #expect(recorder.events == ["discard-partial"])
        await template.close()
        try await template.discard()
    }

    @Test("Change Bike preserves the demo and re-entry after relaunch restores its changes")
    func changeBikeRetainsDemo() async throws {
        let fixture = DemoExperienceTestFixture()
        let template = try await fixture.factory.make(identity: fixture.identity)
        let suite = "fenr.tests.selection.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let selection = DemoSelectionStore(
            defaults: defaults, encoder: JSONEncoder(), decoder: JSONDecoder(),
            makeID: UUID.init, makeDigits: { "987654321" }, now: Date.init
        )
        try selection.save(fixture.identity)
        let recorder = DemoTransitionRecorder()
        let real = AppExperience(id: UUID(), root: template.root, demoViewModel: nil, close: {}, discard: {})
        let controller = AppExperienceController(
            selectionStore: selection, makeReal: { real },
            makeDemo: { _ in template }, discardDemo: { _ in recorder.record("discard") }
        )
        controller.restore()
        #expect(await waitUntil { controller.experience?.demoViewModel != nil })
        await template.root.lifecycleController.start()
        let model = try #require(controller.experience?.demoViewModel)
        model.select(id: "charging")
        #expect(await waitUntil { model.viewState.selectedID == "charging" })
        let rides = try fixture.makeRides()
        let maintenance = try fixture.makeMaintenance()
        let trip = try #require(try await rides.loadCompletedTrips(vin: fixture.identity.vin).first)
        let entry = try #require(try await maintenance.loadEntries(vin: fixture.identity.vin).first)
        #expect(await rides.deleteCompletedTrip(id: trip.id, vin: fixture.identity.vin))
        #expect(await maintenance.deleteEntry(id: entry.id, vin: fixture.identity.vin))
        let demoDefaults = try #require(UserDefaults(suiteName: fixture.identity.suiteName))
        demoDefaults.set("retained", forKey: "test.preference")
        controller.changeBike()
        controller.changeBike()
        #expect(await waitUntil { !controller.isBusy && controller.experience?.id == real.id })
        #expect(try selection.load() == nil)
        #expect(try selection.loadSavedIdentity() == fixture.identity)
        #expect(fixture.notifications.cancelledPrefixes == ["demo.\(fixture.identity.id.uuidString).maintenance."])
        #expect(recorder.events.isEmpty)
        let restarted = AppExperienceController(
            selectionStore: selection, makeReal: { real },
            makeDemo: { try await fixture.factory.make(identity: $0) },
            discardDemo: { _ in recorder.record("discard") }
        )
        restarted.restore()
        #expect(await waitUntil { restarted.experience?.id == real.id })
        restarted.startDemo()
        #expect(await waitUntil { restarted.experience?.demoViewModel != nil && !restarted.isBusy })
        let resumed = try #require(restarted.experience)
        #expect(resumed.id == fixture.identity.id)
        #expect(try selection.load() == fixture.identity)
        #expect(resumed.demoViewModel?.viewState.selectedID == "charging")
        #expect(try await rides.loadCompletedTrips(vin: fixture.identity.vin).count == 2)
        #expect(try await maintenance.loadEntries(vin: fixture.identity.vin).count == 1)
        #expect(demoDefaults.string(forKey: "test.preference") == "retained")
        await resumed.close()
        try await resumed.discard()
    }

    @Test("Failed preparation of a saved demo never discards its data")
    func savedDemoFailurePreservesData() async throws {
        let fixture = DemoExperienceTestFixture()
        let template = try await fixture.factory.make(identity: fixture.identity)
        let suite = "fenr.tests.selection.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let selection = DemoSelectionStore(
            defaults: defaults, encoder: JSONEncoder(), decoder: JSONDecoder(),
            makeID: UUID.init, makeDigits: { "987654321" }, now: Date.init
        )
        try selection.save(fixture.identity)
        try selection.deactivate()
        let recorder = DemoTransitionRecorder()
        let real = AppExperience(id: UUID(), root: template.root, demoViewModel: nil, close: {}, discard: {})
        let controller = AppExperienceController(
            selectionStore: selection, makeReal: { real },
            makeDemo: { _ in throw DemoPreparationError.seedingFailed },
            discardDemo: { _ in recorder.record("discard") }
        )
        controller.startDemo()
        #expect(await waitUntil { controller.hasError })
        controller.changeBike()
        #expect(await waitUntil { controller.experience != nil && !controller.isBusy })
        #expect(recorder.events.isEmpty)
        #expect(try selection.loadSavedIdentity() == fixture.identity)
        await template.close()
        try await template.discard()
    }

    @Test("A real experience is built only after demo shutdown completes and uses fresh feature models")
    func realExperienceWaitsForDemoShutdown() async throws {
        let fixture = DemoExperienceTestFixture()
        let template = try await fixture.factory.make(identity: fixture.identity)
        let suite = "fenr.tests.selection.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let selection = DemoSelectionStore(
            defaults: defaults, encoder: JSONEncoder(), decoder: JSONDecoder(),
            makeID: UUID.init, makeDigits: { "987654321" }, now: Date.init
        )
        try selection.save(fixture.identity)
        let recorder = DemoTransitionRecorder()
        let demo = AppExperience(
            id: template.id, root: template.root, demoViewModel: template.demoViewModel,
            close: {
                await recorder.wait(event: "closing-demo")
                await template.close()
                recorder.record("closed-demo")
            }, discard: template.discard
        )
        let controller = AppExperienceController(
            selectionStore: selection,
            makeReal: {
                recorder.record("build-real")
                let root = try ProductionAppDependencyContainerFactory.makeDefault(
                    maintenanceReminderScheduler: NoOpMaintenanceReminderScheduler()
                ).makeRootDependencies()
                return AppExperience(id: UUID(), root: root, demoViewModel: nil, close: {}, discard: {})
            },
            makeDemo: { _ in demo }, discardDemo: { _ in recorder.record("unexpected-discard") }
        )
        controller.restore()
        #expect(await waitUntil { controller.experience != nil && !controller.isBusy })
        await template.root.lifecycleController.start()
        controller.changeBike()
        controller.changeBike()
        #expect(await waitUntil { recorder.isWaiting })
        #expect(controller.experience == nil)
        #expect(recorder.events == ["closing-demo"])
        recorder.resume()
        #expect(await waitUntil { controller.experience != nil && !controller.isBusy })
        #expect(recorder.events == ["closing-demo", "closed-demo", "build-real"])
        let real = try #require(controller.experience)
        #expect(real.demoViewModel == nil)
        #expect(real.id != demo.id)
        #expect(real.root.featureStore.onboardingViewModel !== demo.root.featureStore.onboardingViewModel)
        #expect(real.root.featureStore.appSettingsViewModel !== demo.root.featureStore.appSettingsViewModel)
        #expect(real.root.featureStore.powerModeSettingsViewModel !== demo.root.featureStore.powerModeSettingsViewModel)
        #expect(real.root.chargeControlSession !== demo.root.chargeControlSession)
        #expect(try selection.load() == nil)
        #expect(try selection.loadSavedIdentity() == fixture.identity)
        await real.root.shutDown()
        try await template.discard()
    }

}
