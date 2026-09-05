import BikeEmulator
import Foundation
import StarkProtocol
import Testing

@MainActor
@Suite("Demo persistence")
struct DemoPersistenceTests {
    @Test("Recovery preserves unreadable legacy identity bytes without keeping the demo selected")
    func preservesUnreadableLegacySelection() throws {
        let suite = "fenr.tests.demo.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let data = Data("invalid".utf8)
        defaults.set(data, forKey: "com.fenr.experience.demo.v1")
        let store = DemoSelectionStore(
            defaults: defaults, encoder: JSONEncoder(), decoder: JSONDecoder(),
            makeID: UUID.init, makeDigits: { "123456789" }, now: Date.init
        )
        try store.deactivate()
        #expect(try store.load() == nil)
        #expect(defaults.data(forKey: "com.fenr.experience.saved-demo.v1") == data)
    }

    @Test("Demo selection is explicit, stable and does not replace a real profile")
    func selectionIsIndependent() throws {
        let suite = "fenr.tests.demo.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("FENRTEST000000002", forKey: "com.fenr.bikeProfile.vin")
        let store = DemoSelectionStore(
            defaults: defaults, encoder: JSONEncoder(), decoder: JSONDecoder(),
            makeID: UUID.init, makeDigits: { "123456789" }, now: Date.init
        )
        #expect(try store.load() == nil)
        let identity = try store.makeIdentity()
        #expect(StarkPairingIdentity.isValidVIN(identity.vin))
        try store.save(identity)
        #expect(try store.load() == identity)
        try store.deactivate()
        #expect(try store.load() == nil)
        #expect(defaults.string(forKey: "com.fenr.bikeProfile.vin") == "FENRTEST000000002")
        #expect(try store.loadSavedIdentity() == identity)
    }

    @Test("Leaving a legacy active demo retains its identity without selecting it on relaunch")
    func retainsLegacySelection() throws {
        let suite = "fenr.tests.demo.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let identity = DemoIdentity(id: UUID(), vin: "FENRTEST123456789", createdAt: Date())
        defaults.set(try JSONEncoder().encode(identity), forKey: "com.fenr.experience.demo.v1")
        let store = DemoSelectionStore(
            defaults: defaults, encoder: JSONEncoder(), decoder: JSONDecoder(),
            makeID: UUID.init, makeDigits: { "987654321" }, now: Date.init
        )
        #expect(try store.loadSavedIdentity() == identity)
        try store.deactivate()
        let reopened = DemoSelectionStore(
            defaults: defaults, encoder: JSONEncoder(), decoder: JSONDecoder(),
            makeID: UUID.init, makeDigits: { "987654321" }, now: Date.init
        )
        #expect(try reopened.load() == nil)
        #expect(try reopened.loadSavedIdentity() == identity)
    }

    @Test("Confirmed emulator state survives a new store instance and late saves are ignored after disposal")
    func stateIsDurable() throws {
        let suite = "fenr.tests.demo.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = DemoStateStore(
            vin: "FENRTEST000000001", defaults: defaults,
            encoder: JSONEncoder(), decoder: JSONDecoder(), lock: NSLock()
        )
        var state = BikeEmulatorState(scenario: .charging)
        state.chargePowerWatts = 2_100
        state.chargeTargetPercent = 88
        store.save(state)
        let reopened = DemoStateStore(
            vin: "FENRTEST000000001", defaults: defaults,
            encoder: JSONEncoder(), decoder: JSONDecoder(), lock: NSLock()
        )
        #expect(try reopened.load() == state)
        store.invalidate()
        store.save(.init())
        #expect(try reopened.load() == state)
        defaults.set(Data("invalid".utf8), forKey: "emulator.state.v2")
        #expect(throws: (any Error).self) { try reopened.load() }
    }

    @Test("Legacy simulation state gains its VIN and cannot be loaded for a different bike")
    func emulatorStateHasVIN() throws {
        let suite = "fenr.tests.demo.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var state = BikeEmulatorState(scenario: .charging)
        state.chargeTargetPercent = 83
        defaults.set(try JSONEncoder().encode(state), forKey: "emulator.state.v1")
        let store = DemoStateStore(
            vin: "FENRTEST000000001", defaults: defaults,
            encoder: JSONEncoder(), decoder: JSONDecoder(), lock: NSLock()
        )
        #expect(try store.load() == state)
        let data = try #require(defaults.data(forKey: "emulator.state.v2"))
        let record = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(record["vin"] as? String == "FENRTEST000000001")
        let other = DemoStateStore(
            vin: "FENRTEST000000002", defaults: defaults,
            encoder: JSONEncoder(), decoder: JSONDecoder(), lock: NSLock()
        )
        #expect(throws: (any Error).self) { try other.load() }
        other.save(.init())
        #expect(try store.load() == state)
    }

    @Test("Shutdown also stops a repository started by onboarding")
    func stopsOnboardingRepository() async {
        let fixture = AppLifecycleControllerFixture()
        await fixture.repository.start()
        await fixture.lifecycleController.stopAndWait()
        #expect(await fixture.repository.stopCount() > 0)
    }
}
