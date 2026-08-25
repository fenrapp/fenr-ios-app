import BikeEmulator
import Foundation
import Testing

@MainActor
@Suite("Debug scenario controller")
struct DebugScenarioControllerTests {
    @Test("Rapid selections leave the emulator on the latest scenario")
    func rapidSelectionsKeepLatestScenario() async {
        let suiteName = "DebugScenarioControllerTests.\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Unable to create isolated user defaults")
            return
        }
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let repository = BikeEmulatorRepositoryFactory.make(scenario: .charging)
        let controller = DebugScenarioController(
            repository: repository,
            store: DebugScenarioStore(userDefaults: userDefaults)
        )

        controller.select(.riding)
        controller.select(.charging)
        controller.select(.cellAnomaly)

        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(1))
        while await repository.currentScenario() != .cellAnomaly, clock.now < deadline {
            await Task.yield()
        }

        #expect(await repository.currentScenario() == .cellAnomaly)
        #expect(controller.selectedScenario == .cellAnomaly)
        #expect(DebugScenarioStore(userDefaults: userDefaults).load() == .cellAnomaly)
    }
}
