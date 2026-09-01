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
        let profileRepository = DebugBikeProfileRepository()
        let controller = DebugScenarioController(
            repository: repository,
            store: DebugScenarioStore(userDefaults: userDefaults),
            profileRepository: profileRepository
        )

        controller.select(.riding)
        controller.select(.charging)
        controller.select(.cellAnomaly)

        await controller.waitForPendingCommands()

        #expect(await repository.currentScenario() == .cellAnomaly)
        #expect(controller.selectedScenario == .cellAnomaly)
        #expect(DebugScenarioStore(userDefaults: userDefaults).load() == .cellAnomaly)
    }

    @Test("Scenario preset and map selections share one ordered command stream")
    func selectionsAreProcessedInOrder() async throws {
        let suiteName = "DebugScenarioControllerTests.ordered.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let repository = BikeEmulatorRepositoryFactory.make(scenario: .charging)
        let profileRepository = DebugBikeProfileRepository(
            initialProfile: .init(vin: BikeEmulatorIdentity.vin)
        )
        let controller = DebugScenarioController(
            repository: repository,
            store: DebugScenarioStore(userDefaults: userDefaults),
            profileRepository: profileRepository
        )
        await repository.start()

        controller.select(.riding)
        controller.select(.alpha)
        controller.selectMap(5)
        controller.select(.cellAnomaly)
        controller.select(.standard)
        controller.selectMap(2)
        await controller.waitForPendingCommands()

        let stream = await repository.observeTelemetry()
        var iterator = stream.makeAsyncIterator()
        let telemetry = try #require(await iterator.next())
        let profile = try #require(await profileRepository.loadProfile())

        #expect(await repository.currentScenario() == .cellAnomaly)
        #expect(telemetry.mode == .index(2))
        #expect(telemetry.detectedPowerTier == .standardBaseline)
        #expect(profile.declaredPowerTier == .standard)
        #expect(controller.selectedScenario == .cellAnomaly)
        #expect(controller.selectedPowerModePreset == .standard)
        #expect(controller.selectedMap == 2)
    }
}
