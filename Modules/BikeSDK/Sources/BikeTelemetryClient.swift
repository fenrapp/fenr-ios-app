public protocol BikeTelemetryClient: AnyObject, Sendable {
    func start() async
    func stop() async
    func connect(to vin: String) async throws
    func startBikeDiscovery() async
    func stopBikeDiscovery() async
    func disconnect() async throws
    func retrySecurityHandshake() async throws
    func readTelemetrySnapshot() async throws
    func readBikeStatusSnapshot() async throws
    func startBatteryHealthMonitoring() async throws
    func stopBatteryHealthMonitoring() async
    func events() async -> AsyncStream<BikeSDKEvent>
}

public extension BikeTelemetryClient {
    func readBikeStatusSnapshot() async throws {}
}
