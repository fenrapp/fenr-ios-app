import BikeDomain
import BikeEmulator
import Testing

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
        let repository = BikeEmulatorRepositoryFactory.make()
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
        let repository = BikeEmulatorRepositoryFactory.make(scenario: .riding)

        await repository.start()
        let stream = await repository.observeTelemetry()
        var iterator = stream.makeAsyncIterator()
        let initialTelemetry = try await nextValue(from: &iterator)
        try await Task.sleep(for: .milliseconds(600))
        let movingTelemetry = try await nextValue(from: &iterator)
        try await repository.startBatteryHealthMonitoring()
        let health = try await nextValue(from: await repository.observeBatteryHealth())

        #expect(initialTelemetry.speed.kmh == .zero)
        #expect(movingTelemetry.speed.kmh ?? .zero > .zero)
        #expect(movingTelemetry.motorRPM.value ?? .zero > .zero)
        #expect(!movingTelemetry.statusFlags.isCharging)
        #expect(movingTelemetry.batteryLevel.percent == health.stateOfCharge.percent)
    }

    @Test("Debug scenarios evolve their live dashboard values")
    func debugScenariosEvolveTheirLiveDashboardValues() async throws {
        let chargingRepository = BikeEmulatorRepositoryFactory.make(scenario: .charging)
        try await chargingRepository.startBatteryHealthMonitoring()
        await chargingRepository.start()
        let chargingStream = await chargingRepository.observeBatteryHealth()
        var chargingIterator = chargingStream.makeAsyncIterator()
        let initialChargingHealth = try await nextValue(from: &chargingIterator)
        try await Task.sleep(nanoseconds: 600_000_000)
        let updatedChargingHealth = try await nextValue(from: &chargingIterator)

        #expect(updatedChargingHealth.stateOfCharge.percent != initialChargingHealth.stateOfCharge.percent)
        #expect(
            updatedChargingHealth.chargingStatus?.reportedCurrentAmperes
                != initialChargingHealth.chargingStatus?.reportedCurrentAmperes
        )
        #expect(updatedChargingHealth.chargingStatus?.maximumPowerWatts == 1_000)

        let ridingRepository = BikeEmulatorRepositoryFactory.make(scenario: .riding)
        await ridingRepository.start()
        let telemetryStream = await ridingRepository.observeTelemetry()
        var telemetryIterator = telemetryStream.makeAsyncIterator()
        let initialTelemetry = try await nextValue(from: &telemetryIterator)
        try await Task.sleep(nanoseconds: 600_000_000)
        let updatedTelemetry = try await nextValue(from: &telemetryIterator)

        #expect(updatedTelemetry.speed.kmh != initialTelemetry.speed.kmh)
        #expect(updatedTelemetry.statusFlags.indicatorState != initialTelemetry.statusFlags.indicatorState)
    }

    @Test("Charge controls publish and preserve debug values")
    func chargeControlsPublishAndPreserveValues() async throws {
        let repository = BikeEmulatorRepositoryFactory.make(scenario: .charging)
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
        try await Task.sleep(for: .milliseconds(600))
        let tickUpdate = try await nextValue(from: &iterator)
        #expect(tickUpdate.chargingStatus?.maximumPowerWatts == 1_700)
        #expect(tickUpdate.chargingStatus?.maximumStateOfChargePercent == 82)
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
        _ = try await nextValue(from: &healthIterator)

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
        let repository = BikeEmulatorRepositoryFactory.make(scenario: .charging)
        try await repository.startBatteryHealthMonitoring()
        try await repository.startBatteryHealthMonitoring()
        await repository.start()
        let initial = try await nextValue(from: await repository.observeBatteryHealth())
        let initialDate = try #require(initial.lastUpdated)

        await repository.stopBatteryHealthMonitoring()
        try await Task.sleep(for: .milliseconds(600))
        let updateWithOneLease = try await nextValue(from: await repository.observeBatteryHealth())

        #expect(updateWithOneLease.chargeState == .charging)
        #expect(try #require(updateWithOneLease.lastUpdated) > initialDate)
    }

    @Test("Selecting a scenario restores deterministic charge control values")
    func selectingScenarioRestoresChargeControlDefaults() async throws {
        let repository = BikeEmulatorRepositoryFactory.make(scenario: .charging)
        try await repository.startBatteryHealthMonitoring()
        let stream = await repository.observeBatteryHealth()
        var iterator = stream.makeAsyncIterator()
        _ = try await nextValue(from: &iterator)

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

    @Test("Power mode presets publish through domain telemetry")
    func powerModePresetsPublishDomainTelemetry() async throws {
        for preset in BikeEmulatorPowerModePreset.allCases where preset != .failure {
            let repository = BikeEmulatorRepositoryFactory.make(
                scenario: .riding,
                powerModePreset: preset,
                activeMap: 5
            )
            await repository.start()
            let telemetry = try await nextValue(from: await repository.observeTelemetry())

            #expect(telemetry.mode == .index(5))
            if preset == .partial {
                #expect(telemetry.activePowerModeConfiguration?.horsepower == nil)
                #expect(telemetry.activePowerModeConfiguration?.powerTractionPercent == 20)
            } else {
                #expect(telemetry.powerModeConfigurations.count == 5)
            }
            if preset == .alpha || preset == .mismatch {
                #expect(!telemetry.detectedPowerTier.alphaEvidence.isEmpty)
            } else {
                #expect(telemetry.detectedPowerTier == .standardBaseline)
            }
            await repository.stop()
        }
    }

    @Test("Active map changes immediately and read failure preserves base telemetry")
    func activeMapAndReadFailure() async throws {
        let repository = BikeEmulatorRepositoryFactory.make(
            scenario: .riding,
            powerModePreset: .failure,
            activeMap: 1
        )
        await repository.start()
        let stream = await repository.observeTelemetry()
        var iterator = stream.makeAsyncIterator()
        let initial = try await nextValue(from: &iterator)

        await repository.setActiveMap(5)
        let updated = try await nextValue(from: &iterator)

        #expect(initial.speed.kmh != nil)
        #expect(updated.mode == .index(5))
        #expect(updated.speed.kmh != nil)
        await #expect(throws: (any Error).self) {
            try await repository.refreshPowerModeConfigurations()
        }
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

extension BikeEmulatorRepositoryTests {
    @Test("Clean riding scenario moves without activating indicators")
    func cleanRidingScenarioHasNoIndicators() async throws {
        let repository = BikeEmulatorRepositoryFactory.make(scenario: .ridingClean)

        await repository.start()
        let stream = await repository.observeTelemetry()
        var iterator = stream.makeAsyncIterator()
        _ = try await nextValue(from: &iterator)
        try await Task.sleep(for: .milliseconds(600))
        let telemetry = try await nextValue(from: &iterator)

        #expect(telemetry.speed.kmh ?? .zero > .zero)
        #expect(telemetry.statusFlags.indicatorState == .init())
        #expect(!telemetry.statusFlags.isBrakeActive)
        #expect(!telemetry.statusFlags.isFaultActive)
    }
}

private enum EmulatorTestError: Error {
    case streamFinished
}
