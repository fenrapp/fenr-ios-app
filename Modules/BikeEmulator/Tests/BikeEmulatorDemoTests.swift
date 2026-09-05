import BikeDomain
@testable import BikeEmulator
import Foundation
import Testing

@Suite("Persistent demo emulator")
struct BikeEmulatorDemoTests {
    @Test("Demo riding never activates either turn signal")
    func ridingWithoutBlinkers() {
        for tick in 0 ..< 36 {
            let telemetry = BikeEmulatorPayloadFactory.makeTelemetry(
                scenario: .riding, tick: tick,
                context: .init(
                    powerModePreset: .alpha, activeMapNumber: 4, chargeTargetPercent: 100,
                    date: Date(timeIntervalSince1970: 1_000), isDemo: true
                ),
                powerCalculator: .init()
            )
            #expect(!telemetry.statusFlags.indicatorState.isLeftBlinkerOn)
            #expect(!telemetry.statusFlags.indicatorState.isRightBlinkerOn)
        }
    }

    @Test("Restores identity, controls and odometer without restoring write preparation")
    func restoresConfirmedState() async throws {
        let repository = makeDemoRepository()
        await repository.start()
        try await repository.preparePowerModeControl(mapIndex: 3)
        try await repository.setPowerModeConfiguration(mapIndex: 3, horsepower: 72, regenerativeBrakingPercent: 33)
        try await repository.prepareTractionControl(mapIndex: 3)
        try await repository.setTractionControlConfiguration(
            mapIndex: 3, powerTractionPercent: -10.5, brakingTractionPercent: 12.3
        )
        _ = try await repository.prepareBikeLockControl()
        _ = try await repository.setBikeLocked(true)
        var state = await repository.persistentState()
        state.distanceKilometers = 42.5
        let encoded = try JSONEncoder().encode(state)
        let restoredState = try JSONDecoder().decode(BikeEmulatorState.self, from: encoded)
        await repository.stop()

        let restored = makeDemoRepository(state: restoredState)
        await restored.start()
        let stream = await restored.observeTelemetry()
        var iterator = stream.makeAsyncIterator()
        let telemetry = try #require(await iterator.next())
        #expect(telemetry.vin == "FENRTEST000000001")
        #expect(await restored.persistentState() == restoredState)
        #expect(telemetry.activePowerModeConfiguration?.horsepower == 72)
        #expect(telemetry.activePowerModeConfiguration?.powerTractionPercent == -10.5)
        #expect(telemetry.activePowerModeConfiguration?.brakingTractionPercent == 12.3)
        await #expect(throws: (any Error).self) { try await restored.setBikeLocked(false) }
        await restored.stop()
    }

    @Test("Scenario changes preserve all confirmed charge values and distance")
    func scenarioPreservesState() async throws {
        let repository = makeDemoRepository(state: .init(scenario: .charging))
        await repository.start()
        _ = try await repository.prepareChargePowerControl(chargingStatus: .init(
            requestedCurrentAmperes: 2.5, reportedCurrentAmperes: 2.5, maximumCurrentAmperes: 8,
            maximumPowerWatts: 1_000, targetCellVoltageVolts: 4.2,
            maximumStateOfChargePercent: 100, chargerType: .standard
        ))
        _ = try await repository.setChargePowerLimit(watts: 1_800)
        _ = try await repository.setChargeTarget(percent: 82)
        await repository.setScenario(.parked)
        let parked = await repository.persistentState()
        await repository.setScenario(.charging)
        let charging = await repository.persistentState()
        #expect(parked.chargePowerWatts == 1_800)
        #expect(charging.chargeTargetPercent == 82)
        #expect(charging.distanceKilometers == parked.distanceKilometers)
        await #expect(throws: (any Error).self) { try await repository.setChargeTarget(percent: 90) }
        await repository.stop()
    }

    @Test("Scenario changes keep session controls usable without reopening their screens")
    func scenarioPreservesSessionPreparation() async throws {
        let repository = makeDemoRepository()
        await repository.start()
        try await repository.preparePowerModeControl(mapIndex: 3)
        try await repository.prepareTractionControl(mapIndex: 3)
        _ = try await repository.prepareBikeLockControl()
        await repository.setScenario(.cellAnomaly)
        try await repository.setPowerModeConfiguration(mapIndex: 3, horsepower: 71, regenerativeBrakingPercent: 31)
        try await repository.setTractionControlConfiguration(
            mapIndex: 3, powerTractionPercent: -10.5, brakingTractionPercent: 12.3
        )
        _ = try await repository.setBikeLocked(true)
        #expect(await repository.persistentState().isBikeLocked)
        await repository.stop()
    }

    @Test("Stopped demo cannot be revived by stale writes or a different VIN")
    func stopsRejectStaleCommands() async throws {
        let repository = makeDemoRepository()
        await repository.start()
        await #expect(throws: (any Error).self) { try await repository.connect(vin: "FENRTEST000000002") }
        await repository.stop()
        await repository.setScenario(.charging)
        #expect(await repository.currentScenario() == .parked)
        await #expect(throws: (any Error).self) { try await repository.prepareBikeLockControl() }
        await #expect(throws: (any Error).self) { try await repository.retrySecurityHandshake() }
    }

    @Test("Malformed persisted state is rejected")
    func rejectsMalformedState() {
        var state = BikeEmulatorState()
        #expect(state.isValid)
        state.distanceKilometers = -.infinity
        #expect(!state.isValid)
        state.distanceKilometers = 0
        state.version = 99
        #expect(!state.isValid)
    }
}
