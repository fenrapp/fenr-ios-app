@testable import BikeSDK
import Foundation
import StarkProtocol
import Testing

@Suite("Bike SDK notification mapping")
struct BikeSDKMappingTests {
    @Test("Notification mapper emits 6001 as BMS fault masks")
    func mapsBatteryStatus() throws {
        let mapper = makeNotificationMapper()
        let event = try mapper.telemetryPayload(
            characteristic: StarkUUIDs.batteryStatus,
            data: Data([
                0x01, 0x00, 0x00, 0x00,
                0x02, 0x00, 0x00, 0x00,
                0, 0, 0, 0, 0, 0, 0, 0
            ])
        )

        #expect(event == .batteryStatus(.init(
            positiveFaultBits: 1,
            negativeFaultBits: 2
        )))
    }

    @Test("Notification mapper emits battery payload")
    func mapsBattery() throws {
        let mapper = makeNotificationMapper()
        let event = try mapper.telemetryPayload(
            characteristic: StarkUUIDs.batterySOC,
            data: BikeSDKPayloadFixtures.battery
        )
        #expect(event == .battery(.init(stateOfChargePercent: 91, stateOfHealthPercent: 99, dcBusRaw: nil)))
    }

    @Test("Notification mapper emits the optional power and battery payloads")
    func mapsPowerAndBatteryPayloads() throws {
        let mapper = makeNotificationMapper()

        let parameters = try mapper.telemetryPayload(
            characteristic: StarkUUIDs.batteryParams,
            data: BikeSDKPayloadFixtures.batteryParameters
        )
        let signals = try mapper.telemetryPayload(
            characteristic: StarkUUIDs.batterySignals,
            data: BikeSDKPayloadFixtures.batterySignals
        )
        let estimations = try mapper.telemetryPayload(
            characteristic: StarkUUIDs.liveEstimation,
            data: BikeSDKPayloadFixtures.liveEstimations
        )

        #expect(parameters == .batteryParameters(.init(seriesCount: 100, parallelCount: 2, capacityRaw: 6_900)))
        #expect(signals == .batterySignals(.init(
            positive: .init(
                voltageCandidateRaw: 4_000,
                temperatureRaw: 2_534,
                humidityRaw: 5_012,
                controlFlags: 1
            ),
            negative: .init(
                voltageCandidateRaw: 3_995,
                temperatureRaw: 2_450,
                humidityRaw: 4_899,
                controlFlags: 2
            ),
            currentRaw: 25
        )))
        #expect(estimations == .liveEstimations(.init(
            estimatedRangeRaw: 300,
            estimatedTimeRaw: 45,
            nativeMotorPowerRaw: -123
        )))
    }

    @Test("Notification debug distinguishes candidates from validated conversions")
    func debugIncludesPowerConversions() throws {
        let mapper = makeNotificationMapper()
        let payload = try mapper.telemetryPayload(
            characteristic: StarkUUIDs.batterySignals,
            data: BikeSDKPayloadFixtures.batterySignals
        )

        let debug = mapper.debug(
            characteristic: StarkUUIDs.batterySignals,
            data: BikeSDKPayloadFixtures.batterySignals,
            payload: payload,
            date: Date(timeIntervalSince1970: 0)
        )

        #expect(debug.decodedDetail?.contains("currentCandidateRaw=25 candidateA=25.0") == true)
        #expect(debug.decodedDetail?.contains("voltageCandidateRaw=4000") == true)
        #expect(debug.decodedDetail?.contains("dcBusV=") == false)
        #expect(debug.decodedDetail?.contains("tempCandidateC=25.34") == true)
        #expect(debug.decodedDetail?.contains("electricalPowerW") == true)
        #expect(debug.decodedDetail?.contains("starkHP") == true)
    }

    @Test("Notification mapper emits speed payload")
    func mapsSpeed() throws {
        let mapper = makeNotificationMapper()
        let event = try mapper.telemetryPayload(
            characteristic: StarkUUIDs.liveSpeed,
            data: BikeSDKPayloadFixtures.speed
        )
        #expect(event == .speed(.init(speedKmh: 42.1, speedKmhX10: 421, motorRPM: 3180)))
    }

    @Test("Notification mapper emits map payload")
    func mapsMap() throws {
        let mapper = makeNotificationMapper()

        let event = try mapper.telemetryPayload(
            characteristic: StarkUUIDs.liveMap,
            data: BikeSDKPayloadFixtures.map
        )

        #expect(event == .map(3))
    }

    @Test("Notification mapper emits charger payload")
    func mapsCharger() throws {
        let mapper = makeNotificationMapper()

        let event = try mapper.telemetryPayload(
            characteristic: StarkUUIDs.chargerData,
            data: BikeSDKPayloadFixtures.charger
        )

        #expect(event == .charger(.init(
            requestedCurrentAmperes: 2.5,
            reportedCurrentAmperes: 2.5,
            targetCellVoltageVolts: 4.275,
            maximumCurrentAmperes: 20,
            maximumPowerWatts: 1_000,
            maximumStateOfChargePercent: 100,
            requestedVoltageRaw: 0,
            reportedVoltageRaw: 0,
            statusRaw: 0,
            isEnabled: false,
            typeRaw: 3
        )))
    }

    @Test("Notification mapper emits decoded status payload")
    func mapsStatus() throws {
        let mapper = makeNotificationMapper()

        let event = try mapper.telemetryPayload(
            characteristic: StarkUUIDs.bikeStatus,
            data: BikeSDKPayloadFixtures.status
        )

        guard case .status(let status) = event else {
            Issue.record("Expected a status telemetry payload")
            return
        }
        #expect(status.isOn)
        #expect(status.isCharging)
        #expect(status.isInGear)
        #expect(status.isFaultActive)
        #expect(status.isCrawlActive)
        #expect(status.isCrawlForward)
    }

    @Test("Notification mapper emits VCU brake payload only for VCU telemetry frames")
    func mapsVCUBrake() throws {
        let mapper = makeNotificationMapper()

        let active = try mapper.telemetryPayload(
            characteristic: StarkUUIDs.vcuTelemetryTLV,
            data: Data([0x05, 0x0F, 0x01, 0x00, 0x00, 0x00, 0x01, 0x00])
        )
        let compactFrame = try mapper.telemetryPayload(
            characteristic: StarkUUIDs.vcuTelemetryTLV,
            data: Data([0x02, 0x0A, 0x02, 0x00, 0x97, 0x00, 0x40, 0x1F])
        )

        #expect(active == .vcuBrake(.init(primaryBrakeSignal: 1, secondaryBrakeSignal: 1)))
        #expect(compactFrame == nil)
    }

    @Test("Notification mapper emits raw inverter temperature readings")
    func mapsInverterTemperatures() throws {
        let mapper = makeNotificationMapper()
        let data = Data([
            0x8B, 0x01, 0x98, 0x01, 0x43, 0x01, 0x07, 0x02,
            0x42, 0x01, 0x45, 0x01, 0x4A, 0x01, 0x00, 0x00
        ])

        let event = try mapper.telemetryPayload(
            characteristic: StarkUUIDs.inverterTemperatures,
            data: data
        )

        #expect(event == .inverterTemperatures(.init(
            motor: .init(rawValues: [395, 408, 323], validStatus: 7, usedStatus: 2),
            igbt: .init(rawValues: [322, 325, 330], validStatus: 0, usedStatus: 0)
        )))
    }

    @Test("Notification mapper accepts unsolicited power and traction configurations")
    func mapsUnsolicitedConfigurations() throws {
        let mapper = makeNotificationMapper()

        let power = try mapper.telemetryPayload(
            characteristic: StarkUUIDs.vcuBikeConfiguration,
            data: Data([2, 0, 0, 0, 38, 0, 70, 0, 0])
        )
        let traction = try mapper.telemetryPayload(
            characteristic: StarkUUIDs.vcuBikeConfiguration,
            data: Data([2, 8, 0, 4, 25, 0, 15, 0])
        )

        #expect(power == .powerModeConfiguration(.init(
            mapIndex: 0,
            torqueRaw: 38,
            regenerationRaw: 70,
            curve: 0
        )))
        #expect(traction == .tractionControlConfiguration(.init(
            mapIndex: 4,
            powerRaw: 25,
            brakingRaw: 15
        )))
    }

    @Test("Unknown characteristic is ignored")
    func unknownCharacteristic() throws {
        let mapper = makeNotificationMapper()
        let event = try mapper.telemetryPayload(characteristic: UUID(), data: Data([1, 2, 3]))
        #expect(event == nil)
    }

    @Test("Notification registry accepts an injected protocol decoder")
    func injectedDecoder() throws {
        let expectedModeIndex = 9
        let registry = StarkNotificationDecoderRegistry(decoders: [
            StarkUUIDs.liveMap: .adapting(
                decoder: FakeStarkMapDecoder(payload: .init(modeIndex: expectedModeIndex)),
                transform: { .map($0.modeIndex) }
            )
        ])
        let mapper = StarkNotificationToSDKEventMapper(decoderRegistry: registry)

        let payload = try mapper.telemetryPayload(
            characteristic: StarkUUIDs.liveMap,
            data: Data()
        )

        #expect(payload == .map(expectedModeIndex))
    }
}
