@testable import BikeSDK
import BLETraceDomain
import CoreBluetooth
import Foundation
import Testing

@MainActor
@Suite("Manual diagnostic admission")
struct BikeBLEManualCaptureTests {
    @Test("First manual capture starts offline and closes on bike change")
    func startsWithoutPreviousConnection() async {
        let recorder = BLETraceRecorderSpy()
        let state = BLETraceCaptureState()
        let emitter = makeTraceEmitter(recorder: recorder, captureState: state)
        await emitter.recordConnectionState(.idle)
        #expect(!state.isRecording)
        #expect(await recorder.recordedEvents().isEmpty)
        #expect(await emitter.startNewCapture(vin: "FENRTEST000000001"))
        #expect(state.isRecording)
        #expect(await recorder.contexts.map(\.reason) == [.manualRequest])
        await emitter.selectBike(vin: "FENRTEST000000001")
        #expect(state.isRecording)
        await emitter.selectBike(vin: "FENRTEST000000002")
        #expect(!state.isRecording)
        #expect(await recorder.endReasons == [.clientStopped])
    }

    @Test("Connect remains silent and disconnect does not end a manual capture")
    func separatesCaptureFromConnection() async throws {
        let recorder = BLETraceRecorderSpy()
        let adapter = FakeCoreBluetoothAdapter()
        adapter.state = .poweredOn
        let coordinator = makeConnectionCoordinator(
            adapter: adapter,
            eventHub: AsyncEventHub<BikeSDKEvent>(bufferingPolicy: .unbounded),
            traceRecorder: recorder
        )
        try await coordinator.connect(to: "FENRTEST000000001")
        #expect(await recorder.contexts.isEmpty)
        try await coordinator.disconnect()
        let scanCount = adapter.scanCount
        #expect(await coordinator.startNewDiagnosticsCapture(vin: "FENRTEST000000001"))
        #expect(adapter.scanCount == scanCount)
        try await coordinator.connect(to: "FENRTEST000000001")
        try await coordinator.disconnect()
        #expect(await recorder.contexts.count == 1)
        #expect(await recorder.endReasons.isEmpty)
        await coordinator.stop()
        #expect(await recorder.endReasons == [.clientStopped])
    }

    @Test("Failed storage never enables capture")
    func failedStorageRemainsInactive() async {
        let state = BLETraceCaptureState()
        let emitter = makeTraceEmitter(captureState: state)
        #expect(await emitter.startNewCapture(vin: "FENRTEST000000001") == false)
        #expect(!state.isRecording)
        #expect(await emitter.stopCapture() == false)
    }

    @Test("Stop propagates a file finalization failure")
    func stopReportsWriterFailure() async {
        let recorder = BLETraceRecorderSpy()
        let state = BLETraceCaptureState()
        let emitter = makeTraceEmitter(recorder: recorder, captureState: state)
        #expect(await emitter.startNewCapture(vin: "FENRTEST000000001"))
        await recorder.failFinish()
        #expect(await emitter.stopCapture() == false)
        #expect(!state.isRecording)
    }

    @Test("Diagnostic message construction is skipped while capture is disabled")
    func avoidsDisabledFormatting() async {
        let state = BLETraceCaptureState()
        let hub = AsyncEventHub<BikeSDKEvent>(bufferingPolicy: .unbounded)
        let emitter = BikeBLEEventEmitter(
            eventHub: hub,
            captureState: state,
            connectionStatusObserver: { _ in }
        )
        var formatted = false
        func diagnostic() -> BikeSDKEvent {
            formatted = true
            return .debug(.init(title: "QA", detail: "synthetic event"))
        }
        await emitter.sendDiagnostic(diagnostic())
        #expect(!formatted)
        state.setRecording(true)
        await emitter.sendDiagnostic(diagnostic())
        #expect(formatted)
    }

    @Test("Restart after writer failure clears read correlation from the previous capture")
    func restartClearsPendingReads() async {
        let recorder = BLETraceRecorderSpy()
        let state = BLETraceCaptureState()
        let emitter = makeTraceEmitter(recorder: recorder, captureState: state)
        let characteristic = CBMutableCharacteristic(
            type: CBUUID(string: "5001"), properties: [.read], value: nil, permissions: [.readable]
        )
        #expect(await emitter.startNewCapture(vin: "FENRTEST000000001"))
        await emitter.recordReadRequested(characteristic: characteristic)

        state.setRecording(false)
        #expect(await emitter.startNewCapture(vin: "FENRTEST000000001"))
        await emitter.recordValueUpdate(characteristic: characteristic, error: nil)

        let update = await recorder.recordedEvents().last { $0.operation == .valueUpdated }
        #expect(update?.readPending == false)
    }
}
