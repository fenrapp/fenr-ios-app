import BikeDomain
@testable import BikeEmulator
import Foundation
import Testing

@Suite("Demo advanced curves")
struct BikeEmulatorDemoCurveTests {
    @Test("All five demo maps allow curve editing with sibling values preserved", arguments: 0 ..< 5)
    func editsAndRestores(mapIndex: Int) async throws {
        let repository = makeDemoRepository()
        await repository.start()
        #expect(repository.supportsAdvancedPowerModes)
        let baseline = try await repository.readAdvancedPowerMode(mapIndex: mapIndex)
        var desired = baseline
        desired.power = baseline.power.map { Int(Double($0) * 0.9) }
        desired.regeneration[7] = baseline.regeneration[7] == 500 ? 600 : 500
        let confirmed = try await repository.applyAdvancedPowerMode(expected: baseline, desired: desired)
        #expect(confirmed == desired)
        #expect(confirmed.powerTractionRaw == baseline.powerTractionRaw)
        #expect(confirmed.brakingTractionRaw == baseline.brakingTractionRaw)
        await repository.setScenario(.charging)
        #expect(try await repository.readAdvancedPowerMode(mapIndex: mapIndex) == desired)
        let saved = await repository.persistentState()
        #expect(saved.isValid)
        let decoded = try JSONDecoder().decode(BikeEmulatorState.self, from: JSONEncoder().encode(saved))
        await repository.stop()
        let restored = makeDemoRepository(state: decoded)
        await restored.start()
        #expect(try await restored.readAdvancedPowerMode(mapIndex: mapIndex) == desired)
        await restored.stop()
    }

    @Test("Stopped demo rejects advanced reads and writes")
    func stoppedDemo() async throws {
        let repository = makeDemoRepository()
        await repository.start()
        let baseline = try await repository.readAdvancedPowerMode(mapIndex: 0)
        await repository.stop()
        await #expect(throws: (any Error).self) { try await repository.readAdvancedPowerMode(mapIndex: 0) }
        await #expect(throws: (any Error).self) {
            try await repository.applyAdvancedPowerMode(expected: baseline, desired: baseline)
        }
    }

    @Test("Rounded basic horsepower does not replace a saved custom curve")
    func preservesFractionalHorsepower() async throws {
        let repository = makeDemoRepository()
        await repository.start()
        let baseline = try await repository.readAdvancedPowerMode(mapIndex: 0)
        var desired = baseline
        desired.torqueRaw = 32
        desired.power = baseline.power.map { Int(Double($0) * 0.8) }
        _ = try await repository.applyAdvancedPowerMode(expected: baseline, desired: desired)
        #expect(try await repository.readAdvancedPowerMode(mapIndex: 0) == desired)
        let saved = await repository.persistentState()
        await repository.stop()
        let restored = makeDemoRepository(state: saved)
        await restored.start()
        #expect(try await restored.readAdvancedPowerMode(mapIndex: 0) == desired)
        await restored.stop()
    }

    @Test("Malformed or duplicate saved curves are rejected")
    func invalidSavedCurves() async throws {
        let repository = makeDemoRepository()
        await repository.start()
        let baseline = try await repository.readAdvancedPowerMode(mapIndex: 0)
        await repository.stop()
        var state = BikeEmulatorState()
        state.advancedMaps = [baseline, baseline]
        #expect(!state.isValid)
        var malformed = baseline
        malformed.power.removeLast()
        state.advancedMaps = [malformed]
        #expect(!state.isValid)
    }

    @Test("Demo supplies a fresh synthetic usage counter")
    func demoHours() throws {
        let date = Date(timeIntervalSince1970: 1_000)
        let telemetry = BikeEmulatorPayloadFactory.makeTelemetry(
            scenario: .riding, tick: 0,
            context: .init(powerModePreset: .alpha, activeMapNumber: 4, chargeTargetPercent: 100,
                           date: date, isDemo: true),
            powerCalculator: .init()
        )
        let counter = try #require(telemetry.experimentalUsageCounter)
        #expect(counter.rawValue == 36_000)
        #expect(counter.sampledAt == date)
    }

    @Test("Older saved demos without curves remain readable")
    func legacyState() throws {
        let data = try JSONEncoder().encode(BikeEmulatorState())
        let decoded = try JSONDecoder().decode(BikeEmulatorState.self, from: data)
        #expect(decoded.advancedMaps == nil)
        #expect(decoded.isValid)
    }
}
