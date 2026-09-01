import BikeDomain
import TestSupport

actor WatchOnboardingRepository: BikeRepository, BikeDiscoveryRepository, BikeProfileRepository {
    private let connections = TestEventHub<BikeConnection>(bufferingPolicy: .unbounded)
    private let discoveredBikes = TestEventHub<[DiscoveredBike]>(bufferingPolicy: .unbounded)
    private let debugEvents = TestEventHub<BikeDebugEvent>(bufferingPolicy: .unbounded)
    private var profile: BikeProfile?
    private(set) var connectedVIN: String?
    private var discoveryStarts = 0
    private var discoveryStops = 0
    private var suspendsDiscoveryStop = false
    private var discoveryStopContinuations: [CheckedContinuation<Void, Never>] = []

    func start() async {}
    func stop() async {}
    func connect(vin: String) async throws { connectedVIN = vin }
    func disconnect() async throws {}
    func retrySecurityHandshake() async throws {}
    func readTelemetrySnapshot() async throws {}
    func observeTelemetry() async -> AsyncStream<BikeTelemetry> { AsyncStream { _ in } }
    func observeConnection() async -> AsyncStream<BikeConnection> { await connections.stream() }
    func observeDebugEvents() async -> AsyncStream<BikeDebugEvent> { await debugEvents.stream() }
    func startBikeDiscovery() async { discoveryStarts += 1 }

    func stopBikeDiscovery() async {
        discoveryStops += 1
        guard suspendsDiscoveryStop else { return }
        await withCheckedContinuation { continuation in
            discoveryStopContinuations.append(continuation)
        }
    }
    func observeDiscoveredBikes() async -> AsyncStream<[DiscoveredBike]> { await discoveredBikes.stream() }
    func loadProfile() async -> BikeProfile? { profile }
    func saveProfile(_ profile: BikeProfile) async { self.profile = profile }
    func clearProfile() async { profile = nil }
    func discoveryStartCount() -> Int { discoveryStarts }
    func discoveryStopCount() -> Int { discoveryStops }
    func suspendDiscoveryStop() { suspendsDiscoveryStop = true }

    func resumeDiscoveryStop() {
        suspendsDiscoveryStop = false
        let continuations = discoveryStopContinuations
        discoveryStopContinuations.removeAll()
        continuations.forEach { $0.resume() }
    }

    func sendConnection(_ connection: BikeConnection) async {
        _ = await connections.waitForSubscriber()
        await connections.send(connection)
    }

    func sendDebugEvent(_ event: BikeDebugEvent) async {
        _ = await debugEvents.waitForSubscriber()
        await debugEvents.send(event)
    }

    func sendDiscoveredBikes(_ bikes: [DiscoveredBike]) async {
        _ = await discoveredBikes.waitForSubscriber()
        await discoveredBikes.send(bikes)
    }
}
