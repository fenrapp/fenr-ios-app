@testable import BikeSDK
import BLETraceDomain
import CoreBluetooth
import Foundation
import StarkProtocol
import Testing
import TestSupport

@MainActor
@Suite("BLE trace emission")
struct BikeBLETraceEmitterTests {
    @Test("Keeps the session marker ahead of callbacks received while the file opens")
    func recordsSessionStartFirst() async {
        let recorder = BLETraceRecorderSpy()
        await recorder.suspendNextStart()
        let emitter = makeTraceEmitter(recorder: recorder)
        let startTask = Task { @MainActor in
            await emitter.startSession(vin: "FENRTEST000000001", reason: .connectionRequest)
        }
        #expect(await waitUntil { await recorder.isStartSuspended() })

        await emitter.record(
            category: "central",
            operation: .restoration,
            direction: .inbound,
            detail: "peripheral_count=1"
        )
        await recorder.resumeStart()
        await startTask.value

        #expect(await recorder.recordedEvents().map(\.operation) == [.sessionStarted, .restoration])
    }

    @Test("Redacts identity and authentication while preserving ordinary payloads")
    func redactsSensitiveValues() async {
        let recorder = BLETraceRecorderSpy()
        let emitter = makeTraceEmitter(recorder: recorder)
        let syntheticVIN = "FENRTEST000000001"
        let alternateSyntheticVIN = "FENRTEST000000002"
        await emitter.startSession(vin: syntheticVIN, reason: .connectionRequest)

        await emitter.record(
            category: "gatt",
            operation: .valueUpdated,
            direction: .inbound,
            characteristicUUID: CBUUID(nsuuid: StarkUUIDs.bikeStatus),
            data: Data([0xAA, 0xBB]),
            detail: "bike=\(syntheticVIN) alternate=\(alternateSyntheticVIN)"
        )
        await emitter.record(
            category: "gatt",
            operation: .writeRequested,
            direction: .outbound,
            characteristicUUID: CBUUID(nsuuid: StarkUUIDs.bikeSecurity),
            data: Data([0x01, 0x02, 0x03])
        )

        let events = await recorder.recordedEvents()
        let ordinary = events.first { $0.characteristicUUID == StarkUUIDs.bikeStatus.uuidString }
        let security = events.first { $0.characteristicUUID == StarkUUIDs.bikeSecurity.uuidString }
        #expect(ordinary?.payloadHex == "AA BB")
        #expect(ordinary?.detail == "bike=[REDACTED_VIN] alternate=[REDACTED_VIN]")
        #expect(security?.payloadHex == nil)
        #expect(security?.payloadRedacted == true)
        #expect(!events.map { $0.detail ?? "" }.joined().contains(syntheticVIN))
        #expect(!events.map { $0.detail ?? "" }.joined().contains(alternateSyntheticVIN))
    }

    @Test("Records every decode result independently from visual sampling")
    func recordsEveryDecodeResult() async {
        let recorder = BLETraceRecorderSpy()
        let emitter = makeTraceEmitter(recorder: recorder)
        await emitter.startSession(vin: "FENRTEST000000001", reason: .connectionRequest)
        let eventHub = AsyncEventHub<BikeSDKEvent>(bufferingPolicy: .unbounded)
        let processor = BikeBLENotificationProcessor(
            eventEmitter: makeEventEmitter(eventHub: eventHub),
            notificationMapper: makeNotificationMapper(),
            debugSampler: BikeNotificationDebugSampler(minimumInterval: 10),
            traceEmitter: emitter
        )
        let date = Date(timeIntervalSince1970: 0)

        _ = await processor.process(
            characteristic: StarkUUIDs.batterySOC,
            data: BikeSDKPayloadFixtures.battery,
            date: date
        )
        _ = await processor.process(
            characteristic: StarkUUIDs.batterySOC,
            data: BikeSDKPayloadFixtures.battery,
            date: date.addingTimeInterval(0.1)
        )

        let decodeEvents = await recorder.recordedEvents().filter { $0.operation == .decodeResult }
        #expect(decodeEvents.count == 2)
        #expect(decodeEvents.allSatisfy { $0.decodeStatus == .decoded })
    }

    @Test("Correlates unmapped and failed decoder results")
    func recordsDecoderOutcomes() async {
        let recorder = BLETraceRecorderSpy()
        let emitter = makeTraceEmitter(recorder: recorder)
        await emitter.startSession(vin: "FENRTEST000000001", reason: .connectionRequest)
        let eventHub = AsyncEventHub<BikeSDKEvent>(bufferingPolicy: .unbounded)
        let processor = BikeBLENotificationProcessor(
            eventEmitter: makeEventEmitter(eventHub: eventHub),
            notificationMapper: makeNotificationMapper(),
            debugSampler: BikeNotificationDebugSampler(minimumInterval: 10),
            traceEmitter: emitter
        )

        _ = await processor.process(characteristic: UUID(), data: Data([0x01]), date: Date())
        _ = await processor.process(characteristic: StarkUUIDs.batterySOC, data: Data(), date: Date())

        let outcomes = await recorder.recordedEvents().compactMap(\.decodeStatus)
        #expect(outcomes == [.unmapped, .failed])
    }

    @Test("Records high-level connection states without vehicle identity")
    func recordsConnectionStates() async {
        let recorder = BLETraceRecorderSpy()
        let emitter = makeTraceEmitter(recorder: recorder)
        await emitter.startSession(vin: "FENRTEST000000001", reason: .connectionRequest)

        await emitter.recordConnectionState(.connecting(
            vin: "FENRTEST000000001",
            peripheralName: "FENRTEST000000001"
        ))
        await emitter.recordConnectionState(.reconnecting(
            vin: "FENRTEST000000001",
            attempt: 2,
            maximumAttempts: 5
        ))

        let events = await recorder.recordedEvents().filter {
            $0.operation == .connectionStateChanged
        }
        #expect(events.map(\.detail) == ["connecting", "reconnecting attempt=2 maximum=5"])
    }
}
