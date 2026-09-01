import BikeDomain
@testable import BikeEmulator
import Testing

@Suite("Bike emulator controls")
struct BikeEmulatorControlTests {
    @Test("Charge writes require preparation and preserve sibling values")
    func chargeWritesRequirePreparation() async throws {
        let repository = BikeEmulatorRepositoryFactory.make(scenario: .charging)

        await #expect(throws: (any Error).self) {
            try await repository.setChargePowerLimit(watts: 1_700)
        }
        await #expect(throws: (any Error).self) {
            try await repository.setChargeTarget(percent: 82)
        }

        let preparation = try await repository.prepareChargePowerControl(
            chargingStatus: chargingStatus()
        )
        let power = try await repository.setChargePowerLimit(watts: 1_700)
        let target = try await repository.setChargeTarget(percent: 82)

        #expect(preparation.didPassNoOpWrite)
        #expect(power.parsedConfig.chargePowerWatts == 1_700)
        #expect(power.parsedConfig.maximumStateOfChargeDeciPercent == 1_000)
        #expect(target.parsedConfig.chargePowerWatts == 1_700)
        #expect(target.parsedConfig.maximumStateOfChargeDeciPercent == 820)
    }

    @Test("Scenario selection invalidates every control preparation")
    func scenarioInvalidatesPreparations() async throws {
        let repository = BikeEmulatorRepositoryFactory.make(
            scenario: .charging,
            powerModePreset: .alpha
        )
        try await prepareAllControls(on: repository)

        await repository.setScenario(.charging)

        await expectPreparationsCleared(on: repository)
    }

    @Test("Disconnect invalidates every control preparation")
    func disconnectInvalidatesPreparations() async throws {
        let repository = BikeEmulatorRepositoryFactory.make(
            scenario: .charging,
            powerModePreset: .alpha
        )
        try await prepareAllControls(on: repository)

        try await repository.disconnect()

        await expectPreparationsCleared(on: repository)
    }

    @Test("Stop invalidates every control preparation")
    func stopInvalidatesPreparations() async throws {
        let fixture = await makeBikeEmulatorTestFixture(
            scenario: .charging,
            powerModePreset: .alpha
        )
        await fixture.repository.start()
        try await prepareAllControls(on: fixture.repository)

        await fixture.repository.stop()

        await expectPreparationsCleared(on: fixture.repository)
    }

    @Test("Power writes preserve traction siblings")
    func powerWritesPreserveTractionSiblings() async throws {
        let repository = BikeEmulatorRepositoryFactory.make(
            scenario: .riding,
            powerModePreset: .alpha
        )
        try await repository.preparePowerModeControl(mapIndex: 3)

        try await repository.setPowerModeConfiguration(
            mapIndex: 3,
            horsepower: 70,
            regenerativeBrakingPercent: -25
        )

        let configuration = await repository.currentPowerModeConfigurations()[3]
        #expect(configuration?.horsepower == 70)
        #expect(configuration?.regenerativeBrakingPercent == -25)
        #expect(configuration?.powerTractionPercent == 30)
        #expect(configuration?.brakingTractionPercent == 15)
    }

    @Test("Signed whole traction writes preserve power siblings")
    func signedTractionWritesPreservePowerSiblings() async throws {
        let repository = BikeEmulatorRepositoryFactory.make(
            scenario: .riding,
            powerModePreset: .alpha
        )
        try await repository.prepareTractionControl(mapIndex: 3)

        try await repository.setTractionControlConfiguration(
            mapIndex: 3,
            powerTractionPercent: -100,
            brakingTractionPercent: 100
        )

        let configuration = await repository.currentPowerModeConfigurations()[3]
        #expect(configuration?.horsepower == 65)
        #expect(configuration?.regenerativeBrakingPercent == 40)
        #expect(configuration?.powerTractionPercent == -100)
        #expect(configuration?.brakingTractionPercent == 100)

        await #expect(throws: (any Error).self) {
            try await repository.setTractionControlConfiguration(
                mapIndex: 3,
                powerTractionPercent: -10.5,
                brakingTractionPercent: 10
            )
        }
        await #expect(throws: (any Error).self) {
            try await repository.setTractionControlConfiguration(
                mapIndex: 3,
                powerTractionPercent: -101,
                brakingTractionPercent: 10
            )
        }
    }

    @Test("Power refresh preserves success and failure behavior")
    func powerRefreshBehavior() async throws {
        let success = BikeEmulatorRepositoryFactory.make(powerModePreset: .standard)
        try await success.refreshPowerModeConfiguration(mapIndex: 0)
        try await success.readBikeStatusSnapshot()

        let failure = BikeEmulatorRepositoryFactory.make(powerModePreset: .failure)
        await #expect(throws: (any Error).self) {
            try await failure.refreshPowerModeConfiguration(mapIndex: 0)
        }
        await #expect(throws: (any Error).self) {
            try await failure.readBikeStatusSnapshot()
        }
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
            var iterator = (await repository.observeTelemetry()).makeAsyncIterator()
            let telemetry = try #require(await iterator.next())

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
        var iterator = (await repository.observeTelemetry()).makeAsyncIterator()
        let initial = try #require(await iterator.next())

        await repository.setActiveMap(5)
        let updated = try #require(await iterator.next())

        #expect(initial.speed.kmh != nil)
        #expect(updated.mode == .index(5))
        #expect(updated.speed.kmh != nil)
        await #expect(throws: (any Error).self) {
            try await repository.refreshPowerModeConfigurations()
        }
        await repository.stop()
    }

    @Test("Bike Lock requires preparation and preserves its debug state")
    func bikeLockControlRequiresPreparation() async throws {
        let repository = BikeEmulatorRepositoryFactory.make(scenario: .ridingClean)

        await #expect(throws: (any Error).self) {
            try await repository.setBikeLocked(true)
        }
        let preparation = try await repository.prepareBikeLockControl()
        let locked = try await repository.setBikeLocked(true)
        let confirmed = try await repository.prepareBikeLockControl()

        #expect(preparation.didPassNoOpWrite)
        #expect(!preparation.isLocked)
        #expect(locked.isLocked)
        #expect(confirmed.isLocked)
    }

    @Test("Traction controls accept only confirmed whole percentages")
    func tractionControlWriteRange() async throws {
        let repository = BikeEmulatorRepositoryFactory.make(
            scenario: .riding,
            powerModePreset: .alpha,
            activeMap: 4
        )
        await repository.start()
        var iterator = (await repository.observeTelemetry()).makeAsyncIterator()
        _ = try #require(await iterator.next())

        try await repository.prepareTractionControl(mapIndex: 3)
        try await repository.setTractionControlConfiguration(
            mapIndex: 3,
            powerTractionPercent: 35,
            brakingTractionPercent: 15
        )
        let confirmed = try #require(await iterator.next())

        #expect(confirmed.powerModeConfigurations[3]?.powerTractionPercent == 35)
        #expect(confirmed.powerModeConfigurations[3]?.brakingTractionPercent == 15)
        await #expect(throws: (any Error).self) {
            try await repository.setTractionControlConfiguration(
                mapIndex: 3,
                powerTractionPercent: 35.5,
                brakingTractionPercent: 15
            )
        }
        await repository.stop()
    }

    private func prepareAllControls(on repository: BikeEmulatorRepository) async throws {
        _ = try await repository.prepareChargePowerControl(chargingStatus: chargingStatus())
        _ = try await repository.prepareBikeLockControl()
        try await repository.preparePowerModeControl(mapIndex: 3)
        try await repository.prepareTractionControl(mapIndex: 3)
    }

    private func expectPreparationsCleared(on repository: BikeEmulatorRepository) async {
        #expect(await repository.preparedPowerModeIndexes.isEmpty)
        #expect(await repository.preparedTractionControlIndexes.isEmpty)
        #expect(await repository.isChargePowerPrepared == false)
        #expect(await repository.isBikeLockPrepared == false)
    }

    private func chargingStatus() -> BikeChargingStatus {
        .init(
            requestedCurrentAmperes: 2.5,
            reportedCurrentAmperes: 2.5,
            maximumCurrentAmperes: 8.5,
            maximumPowerWatts: 1_000,
            targetCellVoltageVolts: 4.2,
            maximumStateOfChargePercent: 100,
            chargerType: .standard
        )
    }
}
