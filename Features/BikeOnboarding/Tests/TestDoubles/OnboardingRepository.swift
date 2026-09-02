import BikeDomain

actor OnboardingRepository: BikeRepository, BikeDiscoveryRepository {
    private var vin: String?
    private var continuation: AsyncStream<BikeConnection>.Continuation?
    private var isObserving = false
    private var discoveryContinuation: AsyncStream<[DiscoveredBike]>.Continuation?
    private var isObservingDiscoveryValue = false
    private var starts = 0
    private var discoveryStarts = 0
    private var discoveryStops = 0
    private var disconnects = 0
    private var suspendsDiscoveryStop = false
    private var discoveryStopContinuations: [CheckedContinuation<Void, Never>] = []

    func start() async { starts += 1 }
    func stop() async {}
    func connect(vin: String) async throws { self.vin = vin }
    func disconnect() async throws {
        disconnects += 1
        vin = nil
    }
    func retrySecurityHandshake() async throws {}
    func readTelemetrySnapshot() async throws {}
    func observeTelemetry() async -> AsyncStream<BikeTelemetry> { .init { _ in } }
    func observeDebugEvents() async -> AsyncStream<BikeDebugEvent> { .init { _ in } }
    func startBikeDiscovery() async { discoveryStarts += 1 }

    func stopBikeDiscovery() async {
        discoveryStops += 1
        guard suspendsDiscoveryStop else { return }
        await withCheckedContinuation { continuation in
            discoveryStopContinuations.append(continuation)
        }
    }

    func observeDiscoveredBikes() async -> AsyncStream<[DiscoveredBike]> {
        AsyncStream { continuation in
            discoveryContinuation = continuation
            isObservingDiscoveryValue = true
        }
    }

    func observeConnection() async -> AsyncStream<BikeConnection> {
        AsyncStream { continuation in
            self.continuation = continuation
            self.isObserving = true
        }
    }

    func connectedVIN() -> String? { vin }
    func startCount() -> Int { starts }
    func discoveryStartCount() -> Int { discoveryStarts }
    func discoveryStopCount() -> Int { discoveryStops }
    func disconnectCount() -> Int { disconnects }
    func isObservingConnection() -> Bool { isObserving }
    func isObservingDiscovery() -> Bool { isObservingDiscoveryValue }
    func suspendDiscoveryStop() { suspendsDiscoveryStop = true }

    func resumeDiscoveryStop() {
        suspendsDiscoveryStop = false
        let continuations = discoveryStopContinuations
        discoveryStopContinuations.removeAll()
        continuations.forEach { $0.resume() }
    }

    func sendConnection(_ connection: BikeConnection) { continuation?.yield(connection) }
    func sendDiscoveredBikes(_ bikes: [DiscoveredBike]) { discoveryContinuation?.yield(bikes) }
}
