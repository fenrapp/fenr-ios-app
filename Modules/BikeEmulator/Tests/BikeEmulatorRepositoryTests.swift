import BikeDomain
import BikeEmulator
import Testing

@Suite("Bike emulator repository")
struct BikeEmulatorRepositoryTests {
    @Test("Charging scenario publishes connected telemetry and charging health")
    func chargingScenarioPublishesChargingData() async throws {
        let repository = BikeEmulatorRepository(scenario: .charging)

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
        let repository = BikeEmulatorRepository(scenario: .charging)
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
        let repository = BikeEmulatorRepository()
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

    @Test("Riding scenario publishes moving telemetry")
    func ridingScenarioPublishesMovingTelemetry() async throws {
        let repository = BikeEmulatorRepository(scenario: .riding)

        await repository.start()
        let telemetry = try await nextValue(from: await repository.observeTelemetry())
        try await repository.startBatteryHealthMonitoring()
        let health = try await nextValue(from: await repository.observeBatteryHealth())

        #expect(telemetry.speed.kmh ?? .zero > .zero)
        #expect(telemetry.motorRPM.value ?? .zero > .zero)
        #expect(telemetry.statusFlags.isInGear)
        #expect(!telemetry.statusFlags.isCharging)
        #expect(telemetry.batteryLevel.percent == health.stateOfCharge.percent)
    }

    @Test("Debug scenarios evolve their live dashboard values")
    func debugScenariosEvolveTheirLiveDashboardValues() async throws {
        let chargingRepository = BikeEmulatorRepository(scenario: .charging)
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
        #expect(
            updatedChargingHealth.chargingStatus?.maximumPowerWatts
                != initialChargingHealth.chargingStatus?.maximumPowerWatts
        )

        let ridingRepository = BikeEmulatorRepository(scenario: .riding)
        await ridingRepository.start()
        let telemetryStream = await ridingRepository.observeTelemetry()
        var telemetryIterator = telemetryStream.makeAsyncIterator()
        let initialTelemetry = try await nextValue(from: &telemetryIterator)
        try await Task.sleep(nanoseconds: 600_000_000)
        let updatedTelemetry = try await nextValue(from: &telemetryIterator)

        #expect(updatedTelemetry.speed.kmh != initialTelemetry.speed.kmh)
        #expect(updatedTelemetry.statusFlags.indicatorState != initialTelemetry.statusFlags.indicatorState)
    }

    @Test("Connection advertises the VIN used by onboarding")
    func connectionAdvertisesTelemetryVIN() async throws {
        let repository = BikeEmulatorRepository()

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
