import BikeDomain
import SettingsDomain
import TestSupport

actor WatchDashboardRepository: BikeRepository, BikeBatteryHealthRepository {
    private let telemetry = TestEventHub<BikeTelemetry>(bufferingPolicy: .unbounded)
    private let connectionStream = AsyncStream<BikeConnection> { _ in }
    private let debugEvents = TestEventHub<BikeDebugEvent>(bufferingPolicy: .unbounded)
    private let health = TestEventHub<BikeBatteryHealth>(bufferingPolicy: .unbounded)
    private(set) var startMonitoringCalls = 0
    private(set) var stopMonitoringCalls = 0
    private var suspendsMonitoringStop = false
    private var monitoringStopContinuations: [CheckedContinuation<Void, Never>] = []

    func start() async {}
    func stop() async {}
    func connect(vin: String) async throws {}
    func disconnect() async throws {}
    func retrySecurityHandshake() async throws {}
    func readTelemetrySnapshot() async throws {}
    func observeTelemetry() async -> AsyncStream<BikeTelemetry> { await telemetry.stream() }
    func observeConnection() async -> AsyncStream<BikeConnection> { connectionStream }
    func observeDebugEvents() async -> AsyncStream<BikeDebugEvent> { await debugEvents.stream() }
    func startBatteryHealthMonitoring() async throws { startMonitoringCalls += 1 }

    func stopBatteryHealthMonitoring() async {
        stopMonitoringCalls += 1
        guard suspendsMonitoringStop else { return }
        await withCheckedContinuation { continuation in
            monitoringStopContinuations.append(continuation)
        }
    }

    func observeBatteryHealth() async -> AsyncStream<BikeBatteryHealth> { await health.stream() }
    func observeBatteryDatasetCaptures() async -> AsyncStream<BatteryDatasetCapture> { AsyncStream { _ in } }
    func send(_ value: BikeTelemetry) async {
        _ = await telemetry.waitForSubscriber()
        await telemetry.send(value)
    }

    func send(_ value: BikeBatteryHealth) async {
        _ = await health.waitForSubscriber()
        await health.send(value)
    }

    func send(_ event: BikeDebugEvent) async {
        _ = await debugEvents.waitForSubscriber()
        await debugEvents.send(event)
    }

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
