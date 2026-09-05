import BikeDomain
@testable import BikeEmulator
import Testing
import TestSupport

@Suite("Bike emulator repository")
struct BikeEmulatorRepositoryTests {
    @Test("Charging scenario publishes connected telemetry and charging health")
    func chargingScenarioPublishesChargingData() async throws {
        let repository = BikeEmulatorRepositoryFactory.make(scenario: .charging)

        await repository.start()
        let telemetry = try await nextValue(from: await repository.observeTelemetry())
        try await repository.startBatteryHealthMonitoring()
        let health = try await nextValue(from: await repository.observeBatteryHealth())

        #expect(telemetry.statusFlags.isCharging)
        #expect(telemetry.speed.kmh == .zero)
        #expect(health.chargeState == .charging)
        #expect(health.chargingStatus?.reportedCurrentAmperes == 2.5)
        #expect(health.chargingStatus?.maximumPowerWatts == 1_000)
        #expect(health.cellVoltages.count == 100)
        #expect(health.temperatures.count == 12)
    }

    @Test("Scenario changes publish cell anomalies to active observers")
    func scenarioChangesPublishCellAnomalies() async throws {
        let repository = BikeEmulatorRepositoryFactory.make(scenario: .charging)
        try await repository.startBatteryHealthMonitoring()
        let stream = await repository.observeBatteryHealth()
        var iterator = stream.makeAsyncIterator()
        _ = try await nextValue(from: &iterator)

        await repository.setScenario(.cellAnomaly)
        let health = try await nextValue(from: &iterator)

        #expect(health.chargeState == .disconnected)
        #expect(health.chargingStatus == nil)
        #expect(health.isFaultActive)
        #expect(health.cellVoltages.contains(where: { $0.volts == 2.85 }))
        #expect(health.cellVoltages.contains(where: { $0.volts == 3.96 }))
    }

    @Test("New observers receive the latest capture for every dataset")
    func newObserversReceiveLatestCaptures() async throws {
        let fixture = await makeBikeEmulatorTestFixture(capturesDiagnostics: true)
        let repository = fixture.repository
        try await repository.startBatteryHealthMonitoring()

        let stream = await repository.observeBatteryDatasetCaptures()
        var iterator = stream.makeAsyncIterator()
        var receivedDatasets = Set<BatteryDataset>()
        for _ in BatteryDataset.allCases {
            let capture = try await nextValue(from: &iterator)
            receivedDatasets.insert(capture.dataset)
        }

        #expect(receivedDatasets == Set(BatteryDataset.allCases))
    }

    @Test("Riding scenario progresses from rest")
    func ridingScenarioProgressesFromRest() async throws {
        let fixture = await makeBikeEmulatorTestFixture(scenario: .riding)
        let repository = fixture.repository

        await repository.start()
        let stream = await repository.observeTelemetry()
        var iterator = stream.makeAsyncIterator()
        let initialTelemetry = try await nextValue(from: &iterator)
        #expect(await waitUntil {
            await fixture.runtime.waiterCount(for: fixture.runtime.telemetryInterval) == 1
        })
        let resumedTick = await fixture.runtime.resumeNext(for: fixture.runtime.telemetryInterval)
        #expect(resumedTick)
        let movingTelemetry = try await nextValue(from: &iterator)
        try await repository.startBatteryHealthMonitoring()
        let health = try await nextValue(from: await repository.observeBatteryHealth())

        #expect(initialTelemetry.speed.kmh == .zero)
        #expect(movingTelemetry.speed.kmh ?? .zero > .zero)
        #expect(movingTelemetry.motorRPM.value ?? .zero > .zero)
        #expect(!movingTelemetry.statusFlags.isCharging)
        #expect(movingTelemetry.batteryLevel.percent == health.stateOfCharge.percent)
        #expect(movingTelemetry.inverterTemperaturesCelsius.compactMap { $0 }.max() != nil)
        await repository.stop()
    }

    @Test("Debug scenarios evolve their live dashboard values")
    func debugScenariosEvolveTheirLiveDashboardValues() async throws {
        let chargingFixture = await makeBikeEmulatorTestFixture(scenario: .charging)
        let chargingRepository = chargingFixture.repository
        try await chargingRepository.startBatteryHealthMonitoring()
        await chargingRepository.start()
        let chargingStream = await chargingRepository.observeBatteryHealth()
        var chargingIterator = chargingStream.makeAsyncIterator()
        let initialChargingHealth = try await nextValue(from: &chargingIterator)
        #expect(await waitUntil {
            await chargingFixture.runtime.waiterCount(
                for: chargingFixture.runtime.telemetryInterval
            ) == 1
        })
        let resumedChargingTick = await chargingFixture.runtime.resumeNext(
            for: chargingFixture.runtime.telemetryInterval
        )
        #expect(resumedChargingTick)
        let updatedChargingHealth = try await nextValue(from: &chargingIterator)

        #expect(updatedChargingHealth.stateOfCharge.percent != initialChargingHealth.stateOfCharge.percent)
        #expect(
            updatedChargingHealth.chargingStatus?.reportedCurrentAmperes
                != initialChargingHealth.chargingStatus?.reportedCurrentAmperes
        )
        #expect(updatedChargingHealth.chargingStatus?.maximumPowerWatts == 1_000)

        let ridingFixture = await makeBikeEmulatorTestFixture(scenario: .riding)
        let ridingRepository = ridingFixture.repository
        await ridingRepository.start()
        let telemetryStream = await ridingRepository.observeTelemetry()
        var telemetryIterator = telemetryStream.makeAsyncIterator()
        let initialTelemetry = try await nextValue(from: &telemetryIterator)
        #expect(await waitUntil {
            await ridingFixture.runtime.waiterCount(for: ridingFixture.runtime.telemetryInterval) == 1
        })
        let resumedRidingTick = await ridingFixture.runtime.resumeNext(
            for: ridingFixture.runtime.telemetryInterval
        )
        #expect(resumedRidingTick)
        let updatedTelemetry = try await nextValue(from: &telemetryIterator)

        #expect(updatedTelemetry.speed.kmh != initialTelemetry.speed.kmh)
        #expect(updatedTelemetry.statusFlags.indicatorState != initialTelemetry.statusFlags.indicatorState)
        await chargingRepository.stop()
        await ridingRepository.stop()
    }

    @Test("Charge controls publish and preserve debug values")
    func chargeControlsPublishAndPreserveValues() async throws {
        let fixture = await makeBikeEmulatorTestFixture(scenario: .charging)
        let repository = fixture.repository
        try await repository.startBatteryHealthMonitoring()
        let stream = await repository.observeBatteryHealth()
        var iterator = stream.makeAsyncIterator()
        let initial = try await nextValue(from: &iterator)

        let preparation = try await repository.prepareChargePowerControl(
            chargingStatus: try #require(initial.chargingStatus)
        )
        #expect(preparation.didPassNoOpWrite)
        #expect(preparation.isFirmwareCompatible)

        _ = try await repository.setChargePowerLimit(watts: 1_700)
        let powerUpdate = try await nextValue(from: &iterator)
        #expect(powerUpdate.chargingStatus?.maximumPowerWatts == 1_700)
        #expect((powerUpdate.chargingStatus?.reportedCurrentAmperes ?? .infinity) <= 1_700 / 388.4)

        _ = try await repository.setChargeTarget(percent: 82)
        let targetUpdate = try await nextValue(from: &iterator)
        #expect(targetUpdate.chargingStatus?.maximumPowerWatts == 1_700)
        #expect(targetUpdate.chargingStatus?.maximumStateOfChargePercent == 82)

        await repository.start()
        _ = try await nextValue(from: &iterator)
        #expect(await waitUntil {
            await fixture.runtime.waiterCount(for: fixture.runtime.telemetryInterval) == 1
        })
        let resumedTick = await fixture.runtime.resumeNext(for: fixture.runtime.telemetryInterval)
        #expect(resumedTick)
        let tickUpdate = try await nextValue(from: &iterator)
        #expect(tickUpdate.chargingStatus?.maximumPowerWatts == 1_700)
        #expect(tickUpdate.chargingStatus?.maximumStateOfChargePercent == 82)
        await repository.stop()
    }

    @Test("Charging stops when the target is below the current battery level")
    func lowerChargeTargetStopsCharging() async throws {
        let repository = BikeEmulatorRepositoryFactory.make(scenario: .charging)
        await repository.start()

        let telemetryStream = await repository.observeTelemetry()
        var telemetryIterator = telemetryStream.makeAsyncIterator()
        _ = try await nextValue(from: &telemetryIterator)

        try await repository.startBatteryHealthMonitoring()
        let healthStream = await repository.observeBatteryHealth()
        var healthIterator = healthStream.makeAsyncIterator()
        let initialHealth = try await nextValue(from: &healthIterator)
        _ = try await repository.prepareChargePowerControl(
            chargingStatus: try #require(initialHealth.chargingStatus)
        )

        _ = try await repository.setChargeTarget(percent: 60)
        let telemetry = try await nextValue(from: &telemetryIterator)
        let health = try await nextValue(from: &healthIterator)

        #expect(!telemetry.statusFlags.isCharging)
        #expect(telemetry.statusFlags.isChargerConnected)
        #expect(health.chargeState == .connected)
        #expect(health.chargingStatus?.reportedCurrentAmperes == .zero)
        #expect(health.chargingStatus?.maximumStateOfChargePercent == 60)
    }

    @Test("Battery health monitoring remains active until every consumer releases its lease")
    func batteryHealthMonitoringUsesSharedLeases() async throws {
        let fixture = await makeBikeEmulatorTestFixture(scenario: .charging)
        let repository = fixture.repository
        try await repository.startBatteryHealthMonitoring()
        try await repository.startBatteryHealthMonitoring()
        await repository.start()
        let stream = await repository.observeBatteryHealth()
        var iterator = stream.makeAsyncIterator()
        let initial = try await nextValue(from: &iterator)
        let initialDate = try #require(initial.lastUpdated)

        await repository.stopBatteryHealthMonitoring()
        #expect(await waitUntil {
            await fixture.runtime.waiterCount(for: fixture.runtime.telemetryInterval) == 1
        })
        let updateDate = initialDate.addingTimeInterval(1)
        let resumedTick = await fixture.runtime.resumeNext(
            for: fixture.runtime.telemetryInterval,
            date: updateDate
        )
        #expect(resumedTick)
        let updateWithOneLease = try await nextValue(from: &iterator)

        #expect(updateWithOneLease.chargeState == .charging)
        #expect(try #require(updateWithOneLease.lastUpdated) > initialDate)
        await repository.stop()
    }

    @Test("Selecting a scenario restores deterministic charge control values")
    func selectingScenarioRestoresChargeControlDefaults() async throws {
        let repository = BikeEmulatorRepositoryFactory.make(scenario: .charging)
        try await repository.startBatteryHealthMonitoring()
        let stream = await repository.observeBatteryHealth()
        var iterator = stream.makeAsyncIterator()
        let initialHealth = try await nextValue(from: &iterator)
        _ = try await repository.prepareChargePowerControl(
            chargingStatus: try #require(initialHealth.chargingStatus)
        )

        _ = try await repository.setChargePowerLimit(watts: 1_700)
        _ = try await nextValue(from: &iterator)
        _ = try await repository.setChargeTarget(percent: 82)
        _ = try await nextValue(from: &iterator)

        await repository.setScenario(.charging)
        let reset = try await nextValue(from: &iterator)

        #expect(reset.chargingStatus?.maximumPowerWatts == 1_000)
        #expect(reset.chargingStatus?.maximumStateOfChargePercent == 100)
    }

    @Test("Connection advertises the VIN used by onboarding")
    func connectionAdvertisesTelemetryVIN() async throws {
        let repository = BikeEmulatorRepositoryFactory.make()

        await repository.start()
        let telemetry = try await nextValue(from: await repository.observeTelemetry())
        let connection = try await nextValue(from: await repository.observeConnection())

        guard case .receivingTelemetry(let advertisedVIN) = connection.state else {
            Issue.record("Expected the emulator to receive telemetry")
            return
        }
        #expect(advertisedVIN == telemetry.vin)
        #expect(connection.peripheralName == telemetry.vin)
        #expect(telemetry.vin == BikeEmulatorIdentity.vin)
        #expect(BikeEmulatorIdentity.vin.count == 17)
    }

    private func nextValue<Value: Sendable>(
        from stream: AsyncStream<Value>
    ) async throws -> Value {
        var iterator = stream.makeAsyncIterator()
        return try await nextValue(from: &iterator)
    }

    private func nextValue<Value: Sendable>(
        from iterator: inout AsyncStream<Value>.Iterator
    ) async throws -> Value {
        guard let value = await iterator.next() else {
            throw EmulatorTestError.streamFinished
        }
        return value
    }
}

private enum EmulatorTestError: Error {
    case streamFinished
}
