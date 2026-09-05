import BikeDomain

actor SessionSpyRepository: BikeRepository {
    private var starts = 0
    private var stops = 0
    private var connections = 0
    private var captureStops = 0
    private var vin: String?
    private var shouldBlockStart = false
    private var startContinuation: CheckedContinuation<Void, Never>?
    private var shouldBlockConnection = false
    private var connectionContinuation: CheckedContinuation<Void, Never>?

    func start() async {
        starts += 1
        guard shouldBlockStart else { return }
        await withCheckedContinuation { continuation in
            startContinuation = continuation
        }
    }
    func stop() async { stops += 1 }
    func connect(vin: String) async throws {
        connections += 1
        self.vin = vin
        guard shouldBlockConnection else { return }
        await withCheckedContinuation { continuation in
            connectionContinuation = continuation
        }
    }
    func disconnect() async throws {}
    func stopDiagnosticsCapture() async -> Bool {
        captureStops += 1
        return true
    }
    func captureStopCount() -> Int { captureStops }
    func retrySecurityHandshake() async throws {}
    func readTelemetrySnapshot() async throws {}
    func observeTelemetry() async -> AsyncStream<BikeTelemetry> { .init { _ in } }
    func observeConnection() async -> AsyncStream<BikeConnection> { .init { _ in } }
    func observeDebugEvents() async -> AsyncStream<BikeDebugEvent> { .init { _ in } }

    func startCount() -> Int { starts }
    func stopCount() -> Int { stops }
    func connectionCount() -> Int { connections }
    func lastVIN() -> String? { vin }
    func blockNextStart() { shouldBlockStart = true }
    func hasPendingStart() -> Bool { startContinuation != nil }
    func resumeStart() {
        shouldBlockStart = false
        startContinuation?.resume()
        startContinuation = nil
    }
    func blockNextConnection() { shouldBlockConnection = true }
    func hasPendingConnection() -> Bool { connectionContinuation != nil }
    func resumeConnection() {
        shouldBlockConnection = false
        connectionContinuation?.resume()
        connectionContinuation = nil
    }
}
