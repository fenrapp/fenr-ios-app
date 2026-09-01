import BikeDomain

actor SessionSpyRepository: BikeRepository {
    private var starts = 0
    private var stops = 0
    private var vin: String?
    private var shouldBlockStart = false
    private var startContinuation: CheckedContinuation<Void, Never>?

    func start() async {
        starts += 1
        guard shouldBlockStart else { return }
        await withCheckedContinuation { continuation in
            startContinuation = continuation
        }
    }
    func stop() async { stops += 1 }
    func connect(vin: String) async throws { self.vin = vin }
    func disconnect() async throws {}
    func retrySecurityHandshake() async throws {}
    func readTelemetrySnapshot() async throws {}
    func observeTelemetry() async -> AsyncStream<BikeTelemetry> { .init { _ in } }
    func observeConnection() async -> AsyncStream<BikeConnection> { .init { _ in } }
    func observeDebugEvents() async -> AsyncStream<BikeDebugEvent> { .init { _ in } }

    func startCount() -> Int { starts }
    func stopCount() -> Int { stops }
    func lastVIN() -> String? { vin }
    func blockNextStart() { shouldBlockStart = true }
    func hasPendingStart() -> Bool { startContinuation != nil }
    func resumeStart() {
        shouldBlockStart = false
        startContinuation?.resume()
        startContinuation = nil
    }
}
