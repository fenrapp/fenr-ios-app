import BikeDomain
import SettingsDomain

actor WatchDashboardRepository: BikeRepository, BikeBatteryHealthRepository {
    private let telemetryStream: AsyncStream<BikeTelemetry>
    private let telemetryContinuation: AsyncStream<BikeTelemetry>.Continuation
    private let connectionStream: AsyncStream<BikeConnection>
    private let debugEventsStream: AsyncStream<BikeDebugEvent>
    private let debugEventsContinuation: AsyncStream<BikeDebugEvent>.Continuation
    private let healthStream: AsyncStream<BikeBatteryHealth>
    private let healthContinuation: AsyncStream<BikeBatteryHealth>.Continuation
    private(set) var startMonitoringCalls = 0
    private(set) var stopMonitoringCalls = 0
    private var suspendsMonitoringStop = false
    private var monitoringStopContinuations: [CheckedContinuation<Void, Never>] = []

    init() {
        let telemetry = AsyncStream.makeStream(of: BikeTelemetry.self)
        telemetryStream = telemetry.stream
        telemetryContinuation = telemetry.continuation
        connectionStream = AsyncStream { _ in }
        let debugEvents = AsyncStream.makeStream(of: BikeDebugEvent.self)
        debugEventsStream = debugEvents.stream
        debugEventsContinuation = debugEvents.continuation
        let health = AsyncStream.makeStream(of: BikeBatteryHealth.self)
        healthStream = health.stream
        healthContinuation = health.continuation
    }

    func start() async {}
    func stop() async {}
    func connect(vin: String) async throws {}
    func disconnect() async throws {}
    func retrySecurityHandshake() async throws {}
    func readTelemetrySnapshot() async throws {}
    func observeTelemetry() async -> AsyncStream<BikeTelemetry> { telemetryStream }
    func observeConnection() async -> AsyncStream<BikeConnection> { connectionStream }
    func observeDebugEvents() async -> AsyncStream<BikeDebugEvent> { debugEventsStream }
    func startBatteryHealthMonitoring() async throws { startMonitoringCalls += 1 }

    func stopBatteryHealthMonitoring() async {
        stopMonitoringCalls += 1
        guard suspendsMonitoringStop else { return }
        await withCheckedContinuation { continuation in
            monitoringStopContinuations.append(continuation)
        }
    }

    func observeBatteryHealth() async -> AsyncStream<BikeBatteryHealth> { healthStream }
    func observeBatteryDatasetCaptures() async -> AsyncStream<BatteryDatasetCapture> { AsyncStream { _ in } }
    func send(_ telemetry: BikeTelemetry) async { telemetryContinuation.yield(telemetry) }
    func send(_ health: BikeBatteryHealth) async { healthContinuation.yield(health) }
    func send(_ event: BikeDebugEvent) async { debugEventsContinuation.yield(event) }

    func suspendMonitoringStop() {
        suspendsMonitoringStop = true
    }

    func resumeMonitoringStop() {
        suspendsMonitoringStop = false
        let continuations = monitoringStopContinuations
        monitoringStopContinuations.removeAll()
        continuations.forEach { $0.resume() }
    }
}

actor WatchDashboardSettingsRepository: AppSettingsRepository {
    private let settings: AppSettings

    init(settings: AppSettings = .init()) {
        self.settings = settings
    }

    func load() -> AppSettings { settings }
    func save(_: AppSettings) {}

    func observe() -> AsyncStream<AppSettings> {
        AsyncStream { continuation in
            continuation.yield(settings)
        }
    }
}
