import BikeDomain
import Foundation
import SettingsDomain

actor BikeLiveActivityRepository: BikeRepository, BikeBatteryHealthRepository {
    private let telemetrySource = AsyncSource<BikeTelemetry>()
    private let batteryHealthSource = AsyncSource<BikeBatteryHealth>()
    private let connectionSource = AsyncSource<BikeConnection>()
    private var monitoringStarts = 0
    private var monitoringStops = 0
    private var delaysNextMonitoringStart = false

    func start() async {}
    func stop() async {}
    func connect(vin: String) async throws {}
    func disconnect() async throws {}
    func retrySecurityHandshake() async throws {}
    func readTelemetrySnapshot() async throws {}

    func observeTelemetry() async -> AsyncStream<BikeTelemetry> {
        await telemetrySource.stream()
    }

    func observeConnection() async -> AsyncStream<BikeConnection> {
        await connectionSource.stream()
    }

    func observeDebugEvents() async -> AsyncStream<BikeDebugEvent> {
        AsyncStream { _ in }
    }

    func startBatteryHealthMonitoring() async throws {
        if delaysNextMonitoringStart {
            delaysNextMonitoringStart = false
            try? await Task.sleep(for: Constants.delayedMonitoringStartDuration)
        }
        monitoringStarts += 1
    }

    func stopBatteryHealthMonitoring() async {
        monitoringStops += 1
    }

    func observeBatteryHealth() async -> AsyncStream<BikeBatteryHealth> {
        await batteryHealthSource.stream()
    }

    func observeBatteryDatasetCaptures() async -> AsyncStream<BatteryDatasetCapture> {
        AsyncStream { _ in }
    }

    func sendTelemetry(_ telemetry: BikeTelemetry) async {
        await telemetrySource.send(telemetry)
    }

    func sendBatteryHealth(_ health: BikeBatteryHealth) async {
        await batteryHealthSource.send(health)
    }

    func sendConnection(_ connection: BikeConnection) async {
        await connectionSource.send(connection)
    }

    func delayNextMonitoringStart() {
        delaysNextMonitoringStart = true
    }

    func monitoringStartCount() -> Int { monitoringStarts }
    func monitoringStopCount() -> Int { monitoringStops }

    private enum Constants {
        static let delayedMonitoringStartDuration: Duration = .milliseconds(100)
    }
}

actor BikeLiveActivitySettingsRepository: AppSettingsRepository {
    func load() async -> AppSettings { .init() }
    func save(_: AppSettings) async {}

    func observe() async -> AsyncStream<AppSettings> {
        AsyncStream { continuation in
            continuation.yield(.init())
        }
    }
}

@MainActor
final class FakeBikeLiveActivityClient: BikeLiveActivityClient {
    private(set) var startCount = 0
    private(set) var updateCount = 0
    private(set) var endCount = 0
    private(set) var lastStartedVIN: String?
    private(set) var lastStartedState: BikeLiveActivityContentState?
    private(set) var updatedStates: [BikeLiveActivityContentState] = []
    private(set) var endedStates: [BikeLiveActivityContentState] = []
    private var active = false

    var isActive: Bool { active }

    func start(vin: String, state: BikeLiveActivityContentState) async throws {
        startCount += 1
        lastStartedVIN = vin
        lastStartedState = state
        active = true
    }

    func update(state: BikeLiveActivityContentState) async {
        updateCount += 1
        updatedStates.append(state)
    }

    func end(state: BikeLiveActivityContentState) async {
        endCount += 1
        endedStates.append(state)
        active = false
    }
}

final class FakeBikeLiveActivityClock: BikeLiveActivityClock, @unchecked Sendable {
    private(set) var now = Date(timeIntervalSinceReferenceDate: 0)

    func advance(by seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
    }
}

private actor AsyncSource<Element: Sendable> {
    private var continuations: [UUID: AsyncStream<Element>.Continuation] = [:]

    func stream() -> AsyncStream<Element> {
        AsyncStream { continuation in
            let id = UUID()
            continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.remove(id) }
            }
        }
    }

    func send(_ value: Element) {
        for continuation in continuations.values {
            continuation.yield(value)
        }
    }

    private func remove(_ id: UUID) {
        continuations[id] = nil
    }
}
