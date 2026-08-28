public protocol BikeRepository: Sendable {
    func start() async
    func stop() async
    func connect(vin: String) async throws
    func disconnect() async throws
    func retrySecurityHandshake() async throws
    func readTelemetrySnapshot() async throws
    func readBikeStatusSnapshot() async throws
    func refreshPowerModeConfigurations() async throws
    func refreshPowerModeConfiguration(mapIndex: Int) async throws
    func refreshTractionControlConfiguration(mapIndex: Int) async throws
    func observeTelemetry() async -> AsyncStream<BikeTelemetry>
    func observeConnection() async -> AsyncStream<BikeConnection>
    func observeDebugEvents() async -> AsyncStream<BikeDebugEvent>
}

public extension BikeRepository {
    func readBikeStatusSnapshot() async throws {}
    func refreshPowerModeConfigurations() async throws {}
    func refreshPowerModeConfiguration(mapIndex _: Int) async throws {}
    func refreshTractionControlConfiguration(mapIndex _: Int) async throws {}
}
