import BikeDomain

actor WatchOnboardingRepository: BikeRepository, BikeDiscoveryRepository, BikeProfileRepository {
    private let connectionStream: AsyncStream<BikeConnection>
    private let connectionContinuation: AsyncStream<BikeConnection>.Continuation
    private let discoveredBikesStream: AsyncStream<[DiscoveredBike]>
    private let discoveredBikesContinuation: AsyncStream<[DiscoveredBike]>.Continuation
    private let debugEventsStream: AsyncStream<BikeDebugEvent>
    private let debugEventsContinuation: AsyncStream<BikeDebugEvent>.Continuation
    private var profile: BikeProfile?
    private(set) var connectedVIN: String?

    init() {
        let connections = AsyncStream.makeStream(of: BikeConnection.self)
        connectionStream = connections.stream
        connectionContinuation = connections.continuation
        let discoveredBikes = AsyncStream.makeStream(of: [DiscoveredBike].self)
        discoveredBikesStream = discoveredBikes.stream
        discoveredBikesContinuation = discoveredBikes.continuation
        let debugEvents = AsyncStream.makeStream(of: BikeDebugEvent.self)
        debugEventsStream = debugEvents.stream
        debugEventsContinuation = debugEvents.continuation
    }

    func start() async {}
    func stop() async {}
    func connect(vin: String) async throws { connectedVIN = vin }
    func disconnect() async throws {}
    func retrySecurityHandshake() async throws {}
    func readTelemetrySnapshot() async throws {}
    func observeTelemetry() async -> AsyncStream<BikeTelemetry> { AsyncStream { _ in } }
    func observeConnection() async -> AsyncStream<BikeConnection> { connectionStream }
    func observeDebugEvents() async -> AsyncStream<BikeDebugEvent> { debugEventsStream }
    func startBikeDiscovery() async {}
    func stopBikeDiscovery() async {}
    func observeDiscoveredBikes() async -> AsyncStream<[DiscoveredBike]> { discoveredBikesStream }
    func loadProfile() async -> BikeProfile? { profile }
    func saveProfile(_ profile: BikeProfile) async { self.profile = profile }
    func clearProfile() async { profile = nil }
    func sendConnection(_ connection: BikeConnection) { connectionContinuation.yield(connection) }
    func sendDebugEvent(_ event: BikeDebugEvent) { debugEventsContinuation.yield(event) }
    func sendDiscoveredBikes(_ bikes: [DiscoveredBike]) { discoveredBikesContinuation.yield(bikes) }
}
