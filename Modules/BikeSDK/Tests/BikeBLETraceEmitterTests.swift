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

    @Test("Stops and starts a fresh capture without changing the BLE connection")
    func manuallyRestartsCapture() async {
        let recorder = BLETraceRecorderSpy()
        let emitter = makeTraceEmitter(recorder: recorder)
        await emitter.startSession(vin: "FENRTEST000000001", reason: .connectionRequest)

        #expect(await emitter.stopCapture())
        await emitter.record(
            category: "gatt",
            operation: .valueUpdated,
            direction: .inbound,
            detail: "ignored while stopped"
        )
        #expect(await emitter.startNewCapture())

        #expect(await recorder.contexts.map(\.reason) == [.connectionRequest, .manualRequest])
        #expect(await recorder.endReasons == [.userStopped])
        #expect(await recorder.recordedEvents().map(\.operation) == [.sessionStarted, .sessionStarted])
    }

    @Test("Disconnect invalidates a manual capture start in flight")
    func disconnectInvalidatesManualStart() async {
        let recorder = BLETraceRecorderSpy()
        let emitter = makeTraceEmitter(recorder: recorder)
        await emitter.startSession(vin: "FENRTEST000000001", reason: .connectionRequest)
        #expect(await emitter.stopCapture())
        await recorder.suspendNextStart()

        let startTask = Task { @MainActor in await emitter.startNewCapture() }
        #expect(await waitUntil { await recorder.isStartSuspended() })
        await emitter.finishSession(reason: .userDisconnected)
        await recorder.resumeStart()

        #expect(await startTask.value == false)
        #expect(await recorder.endReasons == [.userStopped, .userDisconnected])
    }

    @Test("A completed stop cannot be undone by a suspended session marker")
    func suspendedSessionMarkerDoesNotRestoreRecording() async {
        let recorder = BLETraceRecorderSpy()
        await recorder.suspendNextRecord()
        let emitter = makeTraceEmitter(recorder: recorder)

        let startTask = Task { @MainActor in
            await emitter.startSession(vin: "FENRTEST000000001", reason: .connectionRequest)
        }
        #expect(await waitUntil { await recorder.isRecordSuspended() })
        await emitter.finishSession(reason: .userDisconnected)
        await recorder.resumeRecord()
        await startTask.value

        #expect(await emitter.stopCapture() == false)
        #expect(await recorder.endReasons == [.userDisconnected])
    }

    @Test("A new session waits until the previous file finishes closing")
    func sessionStartDoesNotOverlapFinish() async {
        let recorder = BLETraceRecorderSpy()
        let emitter = makeTraceEmitter(recorder: recorder)
        await emitter.startSession(vin: "FENRTEST000000001", reason: .connectionRequest)
        await recorder.suspendNextFinish()

        let finishTask = Task { @MainActor in
            await emitter.finishSession(reason: .userDisconnected)
        }
        #expect(await waitUntil { await recorder.isFinishSuspended() })
        let nextStartTask = Task { @MainActor in
            await emitter.startSession(vin: "FENRTEST000000002", reason: .connectionRequest)
        }
        #expect(await recorder.contexts.count == 1)

        await recorder.resumeFinish()
        await finishTask.value
        await nextStartTask.value

        #expect(await recorder.contexts.count == 2)
        #expect(await emitter.stopCapture())
    }

    @Test("Starting a new capture cannot overlap a suspended stop")
    func manualStartDoesNotOverlapStop() async {
        let recorder = BLETraceRecorderSpy()
        let emitter = makeTraceEmitter(recorder: recorder)
        await emitter.startSession(vin: "FENRTEST000000001", reason: .connectionRequest)
        await recorder.suspendNextFinish()

        let stopTask = Task { @MainActor in await emitter.stopCapture() }
        #expect(await waitUntil { await recorder.isFinishSuspended() })
        #expect(await emitter.startNewCapture() == false)

        await recorder.resumeFinish()
        #expect(await stopTask.value)
        #expect(await emitter.startNewCapture())
        #expect(await recorder.contexts.map(\.reason) == [.connectionRequest, .manualRequest])
    }
}
