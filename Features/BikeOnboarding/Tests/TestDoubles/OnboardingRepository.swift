import BikeDomain

actor OnboardingRepository: BikeRepository, BikeDiscoveryRepository {
    private var vin: String?
    private var continuation: AsyncStream<BikeConnection>.Continuation?
    private var isObserving = false
    private var discoveryContinuation: AsyncStream<[DiscoveredBike]>.Continuation?
    private var isObservingDiscoveryValue = false
    private var starts = 0

    func start() async { starts += 1 }
    func stop() async {}
    func connect(vin: String) async throws { self.vin = vin }
    func disconnect() async throws {}
    func retrySecurityHandshake() async throws {}
    func readTelemetrySnapshot() async throws {}
    func observeTelemetry() async -> AsyncStream<BikeTelemetry> { .init { _ in } }
    func observeDebugEvents() async -> AsyncStream<BikeDebugEvent> { .init { _ in } }
    func startBikeDiscovery() async {}
    func stopBikeDiscovery() async {}

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
    func isObservingConnection() -> Bool { isObserving }
    func isObservingDiscovery() -> Bool { isObservingDiscoveryValue }
    func sendConnection(_ connection: BikeConnection) { continuation?.yield(connection) }
    func sendDiscoveredBikes(_ bikes: [DiscoveredBike]) { discoveryContinuation?.yield(bikes) }
}
