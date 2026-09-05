import BikeEmulator
import BLETraceDomain
import Testing

@Suite("Manual emulator diagnostics")
struct BikeEmulatorDiagnosticsTests {
    @Test("Startup and reconnection do not create captures")
    func defaultOff() async throws {
        let fixture = makeEmulatorDiagnosticsFixture()
        await fixture.repository.start()
        try await fixture.repository.disconnect()
        try await fixture.repository.connect(vin: BikeEmulatorIdentity.vin)
        #expect(await fixture.recorder.starts.isEmpty)
        #expect(!fixture.captureState.isRecording)
        await fixture.repository.stop()
    }

    @Test("Offline start records synthetic data and survives reconnect until explicit stop")
    func offlineStartReconnectStop() async throws {
        let fixture = makeEmulatorDiagnosticsFixture()
        await fixture.repository.start()
        try await fixture.repository.disconnect()
        #expect(await fixture.repository.startNewDiagnosticsCapture(vin: BikeEmulatorIdentity.vin))
        #expect(fixture.captureState.isRecording)
        #expect(await fixture.recorder.events.count == 1)
        try await fixture.repository.connect(vin: BikeEmulatorIdentity.vin)
        #expect(fixture.captureState.isRecording)
        #expect(await fixture.recorder.starts.count == 1)
        #expect(await fixture.repository.stopDiagnosticsCapture())
        #expect(!fixture.captureState.isRecording)
        await fixture.repository.stop()
    }

    @Test("Writer failure never publishes recording and can be retried")
    func failedStart() async {
        let fixture = makeEmulatorDiagnosticsFixture(startsSuccessfully: false)
        await fixture.repository.start()
        #expect(await !fixture.repository.startNewDiagnosticsCapture(vin: BikeEmulatorIdentity.vin))
        #expect(!fixture.captureState.isRecording)
        #expect(await fixture.recorder.events.isEmpty)
        #expect(await !fixture.repository.startNewDiagnosticsCapture(vin: BikeEmulatorIdentity.vin))
        #expect(await fixture.recorder.starts.count == 2)
        await fixture.repository.stop()
    }

    @Test("Stopping the app closes capture and restarting never resumes it")
    func lifecycleStopsCapture() async {
        let fixture = makeEmulatorDiagnosticsFixture()
        await fixture.repository.start()
        #expect(await fixture.repository.startNewDiagnosticsCapture(vin: BikeEmulatorIdentity.vin))
        await fixture.repository.stop()
        #expect(!fixture.captureState.isRecording)
        await fixture.repository.start()
        #expect(!fixture.captureState.isRecording)
        #expect(await fixture.recorder.starts.count == 1)
        await fixture.repository.stop()
    }

    @Test("Failed file finalization is propagated while recording admission closes")
    func failedStop() async {
        let fixture = makeEmulatorDiagnosticsFixture(finishesSuccessfully: false)
        await fixture.repository.start()
        #expect(await fixture.repository.startNewDiagnosticsCapture(vin: BikeEmulatorIdentity.vin))
        #expect(await fixture.repository.stopDiagnosticsCapture() == false)
        #expect(!fixture.captureState.isRecording)
        await fixture.repository.stop()
    }

}
