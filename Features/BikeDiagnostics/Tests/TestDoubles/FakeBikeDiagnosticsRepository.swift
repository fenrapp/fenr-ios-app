import BikeDomain
import TestSupport

actor FakeBikeDiagnosticsRepository: BikeRepository {
    private let state = FakeBikeDiagnosticsRepositoryState()
    private let telemetryHub = TestEventHub<BikeTelemetry>(bufferingPolicy: .unbounded)
    private let connectionHub = TestEventHub<BikeConnection>(bufferingPolicy: .unbounded)
    private let debugHub = TestEventHub<BikeDebugEvent>(bufferingPolicy: .unbounded)

    func start() async { await state.incrementStart() }
    func stop() async { await state.incrementStop() }
    func connect(vin: String) async throws { await state.setConnectedVIN(vin) }
    func disconnect() async throws { await state.setDidDisconnect() }
    func retrySecurityHandshake() async throws { await state.setDidRetrySecurityHandshake() }
    func startNewDiagnosticsCapture() async -> Bool { await state.startNewDiagnosticsCapture() }
    func stopDiagnosticsCapture() async -> Bool { await state.stopDiagnosticsCapture() }
    func readTelemetrySnapshot() async throws { await state.setDidReadTelemetrySnapshot() }

    func observeTelemetry() async -> AsyncStream<BikeTelemetry> {
        await state.incrementTelemetryObserver()
        return await telemetryHub.stream(replay: BikeTelemetry())
    }

    func observeConnection() async -> AsyncStream<BikeConnection> {
        await connectionHub.stream(replay: BikeConnection())
    }

    func observeDebugEvents() async -> AsyncStream<BikeDebugEvent> {
        await debugHub.stream()
    }

    func sendTelemetry(_ telemetry: BikeTelemetry) async {
        _ = await telemetryHub.waitForSubscriber()
        await telemetryHub.send(telemetry)
    }

    func sendDebugEvent(_ event: BikeDebugEvent) async {
        _ = await debugHub.waitForSubscriber()
        await debugHub.send(event)
    }

    func startCount() async -> Int { await state.startCount }
    func stopCount() async -> Int { await state.stopCount }
    func telemetryObserverCount() async -> Int { await state.telemetryObserverCount }
    func connectedVIN() async -> String? { await state.connectedVIN }
    func didDisconnect() async -> Bool { await state.didDisconnect }
    func didRetrySecurityHandshake() async -> Bool { await state.didRetrySecurityHandshake }
    func didReadTelemetrySnapshot() async -> Bool { await state.didReadTelemetrySnapshot }
    func diagnosticsCaptureStartCount() async -> Int { await state.diagnosticsCaptureStartCount }
    func diagnosticsCaptureStopCount() async -> Int { await state.diagnosticsCaptureStopCount }
}

private actor FakeBikeDiagnosticsRepositoryState {
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var telemetryObserverCount = 0
    private(set) var connectedVIN: String?
    private(set) var didDisconnect = false
    private(set) var didRetrySecurityHandshake = false
    private(set) var didReadTelemetrySnapshot = false
    private(set) var diagnosticsCaptureStartCount = 0
    private(set) var diagnosticsCaptureStopCount = 0

    func incrementStart() {
        startCount += 1
    }

    func incrementStop() {
        stopCount += 1
    }

    func incrementTelemetryObserver() {
        telemetryObserverCount += 1
    }

    func setConnectedVIN(_ vin: String) {
        connectedVIN = vin
    }

    func setDidDisconnect() {
        didDisconnect = true
    }

    func setDidRetrySecurityHandshake() {
        didRetrySecurityHandshake = true
    }

    func setDidReadTelemetrySnapshot() {
        didReadTelemetrySnapshot = true
    }

    func startNewDiagnosticsCapture() -> Bool {
        diagnosticsCaptureStartCount += 1
        return true
    }

    func stopDiagnosticsCapture() -> Bool {
        diagnosticsCaptureStopCount += 1
        return true
    }
}
