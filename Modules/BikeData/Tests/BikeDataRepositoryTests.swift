@testable import BikeData
import BikeDomain
import BikeSDK
import Foundation
import Testing
import TestSupport

@Suite("Bike data repository")
struct BikeDataRepositoryTests {
    @Test("Repository maps SDK payloads into domain telemetry after start")
    func mapsTelemetry() async {
        let client = FakeBikeTelemetryClient()
        let repository = makeRepository(client: client)
        await repository.start()
        let stream = await repository.observeTelemetry()
        var iterator = stream.makeAsyncIterator()
        _ = await iterator.next()

        await client.send(.telemetry(BikeDataTelemetryFixtures.battery))
        _ = await iterator.next()
        await client.send(.telemetry(BikeDataTelemetryFixtures.status))
        _ = await iterator.next()
        await client.send(.telemetry(BikeDataTelemetryFixtures.map))
        _ = await iterator.next()
        await client.send(.telemetry(BikeDataTelemetryFixtures.speed))
        let telemetry = await iterator.next()

        #expect(telemetry?.batteryLevel == .known(percent: 76))
        #expect(telemetry?.healthLevel == .unknown)
        #expect(telemetry?.mode == .index(3))
        #expect(telemetry?.speed == .known(kmh: 42.1, kmhX10: 421))
        #expect(telemetry?.motorRPM == .known(3_180))
        #expect(telemetry?.statusFlags.isOn == true)
        #expect(telemetry?.statusFlags.isCharging == true)
        #expect(telemetry?.statusFlags.isInGear == true)
        #expect(telemetry?.statusFlags.isFaultActive == true)
        #expect(telemetry?.statusFlags.crawlState == .forward)
    }

    @Test("Repository maps the VCU combined brake signal")
    func mapsVCUBrake() async {
        let client = FakeBikeTelemetryClient()
        let repository = makeRepository(client: client)
        await repository.start()
        let stream = await repository.observeTelemetry()
        var iterator = stream.makeAsyncIterator()
        _ = await iterator.next()

        await client.send(.telemetry(BikeDataTelemetryFixtures.activeBrake))
        let telemetry = await iterator.next()

        #expect(telemetry?.statusFlags.isBrakeActive == true)
    }

    @Test("Repository maps odometer and inverter temperature readings")
    func mapsTotalsAndInverterTemperatures() async {
        let client = FakeBikeTelemetryClient()
        let repository = makeRepository(client: client)
        await repository.start()
        let stream = await repository.observeTelemetry()
        var iterator = stream.makeAsyncIterator()
        _ = await iterator.next()

        await client.send(.telemetry(BikeDataTelemetryFixtures.liveTotals))
        _ = await iterator.next()
        await client.send(.telemetry(BikeDataTelemetryFixtures.inverterTemperatures))
        let telemetry = await iterator.next()

        #expect(telemetry?.odometer == .known(kilometers: 180.66, centiKilometers: 18_066))
        #expect(telemetry?.inverterTemperatureRawValues == [395, 408, 323, 519, 322, 325, 330, 0])
        #expect(telemetry?.inverterTemperaturesCelsius == [39.5, 40.8, 32.3, 51.9, 32.2, 32.5, 33.0, nil])
    }

    @Test("Repository init does not start client or consume events")
    func repositoryInitHasNoSideEffects() async {
        let client = FakeBikeTelemetryClient()
        _ = makeRepository(client: client)

        #expect(await client.startCount() == 0)
        #expect(await client.eventStreamCount() == 0)
    }

    @Test("Multiple domain observers share one SDK event stream")
    func observersShareSDKStream() async {
        let client = FakeBikeTelemetryClient()
        let repository = makeRepository(client: client)

        await repository.start()
        _ = await repository.observeTelemetry()
        _ = await repository.observeTelemetry()
        _ = await repository.observeBatteryHealth()
        _ = await repository.observeConnection()

        #expect(await client.eventStreamCount() == 1)
    }

    @Test("Battery Health uses the shared repository and maps confirmed SOC data")
    func mapsBatteryHealth() async throws {
        let client = FakeBikeTelemetryClient()
        let repository = makeRepository(client: client)
        await repository.start()
        let stream = await repository.observeBatteryHealth()
        var iterator = stream.makeAsyncIterator()
        _ = await iterator.next()

        try await repository.startBatteryHealthMonitoring()
        await client.send(.telemetry(BikeDataTelemetryFixtures.battery))
        let health = try #require(await iterator.next())

        #expect(await client.batteryHealthStartCount() == 1)
        #expect(health.stateOfCharge == .known(percent: 76))
        #expect(health.dcBusVoltage == .known(volts: 394.8))
    }

    @Test("Battery Health does not emit for unrelated telemetry payloads")
    func skipsUnrelatedBatteryHealthUpdates() async {
        let client = FakeBikeTelemetryClient()
        let repository = makeRepository(client: client)
        let recorder = BatteryHealthEmissionRecorder()
        await repository.start()
        let healthStream = await repository.observeBatteryHealth()
        let healthTask = Task {
            for await health in healthStream {
                await recorder.append(health)
            }
        }
        #expect(await waitUntil { await recorder.count == 1 })

        let telemetryStream = await repository.observeTelemetry()
        var telemetryIterator = telemetryStream.makeAsyncIterator()
        _ = await telemetryIterator.next()
        let connectionStream = await repository.observeConnection()
        var connectionIterator = connectionStream.makeAsyncIterator()
        _ = await connectionIterator.next()

        await client.send(.telemetry(BikeDataTelemetryFixtures.speed))
        _ = await telemetryIterator.next()
        await client.send(.rssi(-42))
        _ = await connectionIterator.next()

        #expect(await recorder.count == 1)
        healthTask.cancel()
    }

    @Test("Battery Health maps confirmed charger limits into the domain")
    func mapsChargingStatus() async throws {
        let client = FakeBikeTelemetryClient()
        let repository = makeRepository(client: client)
        await repository.start()
        let stream = await repository.observeBatteryHealth()
        var iterator = stream.makeAsyncIterator()
        _ = await iterator.next()

        try await repository.startBatteryHealthMonitoring()
        await client.send(.telemetry(BikeDataTelemetryFixtures.charger))
        let health = try #require(await iterator.next())

        #expect(health.chargingStatus?.reportedCurrentAmperes == 2.5)
        #expect(health.chargingStatus?.maximumPowerWatts == 1_000)
        #expect(health.chargingStatus?.targetCellVoltageVolts == 4.275)
    }

    @Test("Charge power preparation passes charger maximum current, not live requested current")
    func prepareChargePowerUsesMaximumCurrent() async throws {
        let client = FakeBikeTelemetryClient()
        let repository = makeRepository(client: client)
        let chargingStatus = BikeChargingStatus(
            requestedCurrentAmperes: 1.2,
            reportedCurrentAmperes: 1.1,
            maximumCurrentAmperes: 2.0,
            maximumPowerWatts: 500,
            targetCellVoltageVolts: 4.275,
            maximumStateOfChargePercent: 100,
            chargerType: .backpack
        )

        _ = try await repository.prepareChargePowerControl(chargingStatus: chargingStatus)
        let context = try #require(await client.chargePowerContext())

        #expect(context.requestedCurrentAmperes == 1.2)
        #expect(context.maximumCurrentAmperes == 2.0)
        #expect(context.maximumPowerWatts == 500)
        #expect(context.chargerTypeRaw == 3)
    }

    @Test("Battery Health retains only the latest capture for each dataset")
    func mapsBatteryDatasetCapture() async throws {
        let client = FakeBikeTelemetryClient()
        let repository = makeRepository(client: client)
        await repository.start()
        let stream = await repository.observeBatteryDatasetCaptures()
        var iterator = stream.makeAsyncIterator()

        await client.send(.batteryDatasetCapture(.init(
            dataset: .cellVoltages,
            byteCount: 200,
            hex: "AA BB",
            date: .init(timeIntervalSince1970: 0)
        )))
        let capture = try #require(await iterator.next())

        #expect(capture.dataset == .cellVoltages)
        #expect(capture.byteCount == 200)
        #expect(capture.hex == "AA BB")
    }

    @Test("Connection mapper distinguishes subscriptions from received telemetry")
    func mapsTelemetryConnectionState() {
        let mapper = BikeSDKConnectionStatusToDomainMapper()

        #expect(
            mapper.map(.authenticating(peripheralName: "VIN"))
                == .authenticating(peripheralName: "VIN")
        )
        #expect(
            mapper.map(.authenticated(peripheralName: "VIN"))
                == .authenticated(peripheralName: "VIN")
        )
        #expect(mapper.map(.subscribed(peripheralName: "VIN")) == .subscribed(peripheralName: "VIN"))
        #expect(
            mapper.map(.receivingTelemetry(peripheralName: "VIN"))
                == .receivingTelemetry(peripheralName: "VIN")
        )
        #expect(
            mapper.map(.pairingResetRequired(message: "Forget and re-pair"))
                == .pairingResetRequired(message: "Forget and re-pair")
        )
    }

    @Test("Restores persisted Alpha evidence when the matching VIN returns")
    func restoresPersistedAlphaEvidence() async throws {
        let profileRepository = ControllableBikeProfileRepository(profile: .init(
            vin: "FENRTEST000000001",
            alphaEvidence: [.powerAboveStandard],
            alphaDetectedAt: .now
        ))
        let client = FakeBikeTelemetryClient()
        let repository = makeRepository(client: client, profileRepository: profileRepository)
        await repository.start()
        let stream = await repository.observeTelemetry()
        var iterator = stream.makeAsyncIterator()
        _ = await iterator.next()

        await client.send(.telemetry(.vin("FENRTEST000000001")))
        let telemetry = try #require(await iterator.next())

        #expect(telemetry.detectedPowerTier.alphaEvidence == [.powerAboveStandard])
    }

    @Test("Persists new Alpha evidence without later Standard data removing it")
    func persistsAlphaEvidence() async throws {
        let profileRepository = ControllableBikeProfileRepository(
            profile: .init(vin: "FENRTEST000000001")
        )
        let client = FakeBikeTelemetryClient()
        let observedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let repository = makeRepository(
            client: client,
            profileRepository: profileRepository,
            now: { observedAt }
        )
        await repository.start()
        let stream = await repository.observeTelemetry()
        var iterator = stream.makeAsyncIterator()
        _ = await iterator.next()

        await client.send(.telemetry(.vin("FENRTEST000000001")))
        _ = await iterator.next()
        await client.send(.telemetry(.powerModeConfiguration(.init(
            mapIndex: 4,
            torqueRaw: 100,
            regenerationRaw: 0,
            curve: 0
        ))))
        _ = await iterator.next()
        await client.send(.telemetry(.powerModeConfiguration(.init(
            mapIndex: 4,
            torqueRaw: 75,
            regenerationRaw: 0,
            curve: 0
        ))))
        _ = await iterator.next()

        let profile = try #require(await profileRepository.loadProfile())
        #expect(profile.alphaEvidence == [.powerAboveStandard])
        #expect(profile.alphaDetectedAt == observedAt)
    }
}

extension BikeDataRepositoryTests {
    @Test("Battery Health maps 6001 as BMS faults without inventing state of health")
    func mapsBMSStatusFaults() async throws {
        let client = FakeBikeTelemetryClient()
        let repository = makeRepository(client: client)
        await repository.start()
        let stream = await repository.observeBatteryHealth()
        var iterator = stream.makeAsyncIterator()
        _ = await iterator.next()

        await client.send(.telemetry(BikeDataTelemetryFixtures.batteryStatusFault))
        let health = try #require(await iterator.next())

        #expect(health.isFaultActive)
        #expect(health.positiveBMSFaultBits == 1)
        #expect(health.negativeBMSFaultBits == 0)
        #expect(health.stateOfHealth == .unknown)
    }

    @Test("Connection observers do not receive unchanged state")
    func skipsDuplicateConnectionUpdates() async {
        let client = FakeBikeTelemetryClient()
        let repository = makeRepository(client: client)
        let recorder = ConnectionEmissionRecorder()
        await repository.start()
        let connectionStream = await repository.observeConnection()
        let connectionTask = Task {
            for await connection in connectionStream {
                await recorder.append(connection)
            }
        }
        #expect(await waitUntil { await recorder.count == 1 })

        await client.send(.rssi(-42))
        #expect(await waitUntil { await recorder.count == 2 })
        await client.send(.rssi(-42))
        await client.send(.peripheral(name: "Bike", identifier: UUID()))
        #expect(await waitUntil { await recorder.count >= 3 })

        #expect(await recorder.count == 3)
        connectionTask.cancel()
    }
}

private actor BatteryHealthEmissionRecorder {
    private(set) var count = 0

    func append(_: BikeBatteryHealth) {
        count += 1
    }
}

private actor ConnectionEmissionRecorder {
    private(set) var count = 0

    func append(_: BikeConnection) {
        count += 1
    }
}
