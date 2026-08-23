import BikeDomain

actor WatchDashboardRepository: BikeRepository, BikeBatteryHealthRepository {
    private let telemetryStream: AsyncStream<BikeTelemetry>
    private let telemetryContinuation: AsyncStream<BikeTelemetry>.Continuation
    private let connectionStream: AsyncStream<BikeConnection>
    private let healthStream: AsyncStream<BikeBatteryHealth>
    private(set) var startMonitoringCalls = 0

    init() {
        let telemetry = AsyncStream.makeStream(of: BikeTelemetry.self)
        telemetryStream = telemetry.stream
        telemetryContinuation = telemetry.continuation
        connectionStream = AsyncStream { _ in }
        healthStream = AsyncStream { _ in }
    }

    func start() async {}
    func stop() async {}
    func connect(vin: String) async throws {}
    func disconnect() async throws {}
    func retrySecurityHandshake() async throws {}
    func readTelemetrySnapshot() async throws {}
    func observeTelemetry() async -> AsyncStream<BikeTelemetry> { telemetryStream }
    func observeConnection() async -> AsyncStream<BikeConnection> { connectionStream }
    func observeDebugEvents() async -> AsyncStream<BikeDebugEvent> { AsyncStream { _ in } }
    func startBatteryHealthMonitoring() async throws { startMonitoringCalls += 1 }
    func stopBatteryHealthMonitoring() async {}
    func observeBatteryHealth() async -> AsyncStream<BikeBatteryHealth> { healthStream }
    func observeBatteryDatasetCaptures() async -> AsyncStream<BatteryDatasetCapture> { AsyncStream { _ in } }
    func send(_ telemetry: BikeTelemetry) async { telemetryContinuation.yield(telemetry) }
}
