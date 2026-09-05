import BikeDomain
import EnvironmentDomain
import Foundation
import SettingsDomain
import TestSupport
import VehicleSession

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
    private var settings = AppSettings()
    private let hub = TestEventHub<AppSettings>(bufferingPolicy: .bufferingNewest(1))

    func load() async -> AppSettings { settings }
    func save(_ settings: AppSettings) async {
        self.settings = settings
        await hub.send(settings)
    }

    func observe() async -> AsyncStream<AppSettings> {
        await hub.stream(replay: settings)
    }
}

@MainActor
final class FakeBikeLiveActivityClient: BikeLiveActivityClient {
    private(set) var startCount = 0
    private(set) var updateCount = 0
    private(set) var endCount = 0
    private(set) var dismissCount = 0
    private(set) var lastStartedVIN: String?
    private(set) var lastStartedState: BikeLiveActivityContentState?
    private(set) var updatedStates: [BikeLiveActivityContentState] = []
    private(set) var endedStates: [BikeLiveActivityContentState] = []
    private var active = false
    private var delaysNextStart = false
    private var blocksNextUpdate = false
    private var updateContinuation: CheckedContinuation<Void, Never>?

    var isActive: Bool { active }

    func start(vin: String, state: BikeLiveActivityContentState) async throws {
        if delaysNextStart {
            delaysNextStart = false
            try? await Task.sleep(for: Constants.delayedStartDuration)
        }
        startCount += 1
        lastStartedVIN = vin
        lastStartedState = state
        active = true
    }

    func update(state: BikeLiveActivityContentState) async {
        if blocksNextUpdate {
            blocksNextUpdate = false
            await withCheckedContinuation { continuation in
                updateContinuation = continuation
            }
        }
        updateCount += 1
        updatedStates.append(state)
    }

    func end(state: BikeLiveActivityContentState) async {
        endCount += 1
        endedStates.append(state)
        active = false
    }

    func dismiss(state: BikeLiveActivityContentState) async {
        dismissCount += 1
        await end(state: state)
    }

    func delayNextStart() {
        delaysNextStart = true
    }

    func blockNextUpdate() {
        blocksNextUpdate = true
    }

    var hasPendingUpdate: Bool {
        updateContinuation != nil
    }

    func releasePendingUpdate() {
        updateContinuation?.resume()
        updateContinuation = nil
    }

    private enum Constants {
        static let delayedStartDuration: Duration = .milliseconds(100)
    }
}

final class FakeBikeLiveActivityClock: BikeLiveActivityClock, @unchecked Sendable {
    private(set) var now = Date(timeIntervalSinceReferenceDate: 0)

    func advance(by seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
    }
}

actor ControllableBikeLiveActivityTiming {
    private struct PendingSleep {
        let id: UUID
        let duration: Duration
        let continuation: CheckedContinuation<Void, any Error>
    }

    private var sleeps: [PendingSleep] = []
    private var canceledBeforeRegistration: Set<UUID> = []

    nonisolated func makeTiming() -> BikeLiveActivityTiming {
        BikeLiveActivityTiming { [weak self] duration in
            guard let self else { throw CancellationError() }
            try await self.sleep(for: duration)
        }
    }

    func sleep(for duration: Duration) async throws {
        try Task.checkCancellation()
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                register(id: id, duration: duration, continuation: continuation)
            }
        } onCancel: {
            Task { await self.cancel(id: id) }
        }
    }

    func pendingCount(for duration: Duration) -> Int {
        sleeps.count { $0.duration == duration }
    }

    func resumeFirst(for duration: Duration) {
        guard let index = sleeps.firstIndex(where: { $0.duration == duration }) else { return }
        sleeps.remove(at: index).continuation.resume()
    }

    private func register(
        id: UUID,
        duration: Duration,
        continuation: CheckedContinuation<Void, any Error>
    ) {
        guard canceledBeforeRegistration.remove(id) == nil else {
            continuation.resume(throwing: CancellationError())
            return
        }
        sleeps.append(.init(id: id, duration: duration, continuation: continuation))
    }

    private func cancel(id: UUID) {
        guard let index = sleeps.firstIndex(where: { $0.id == id }) else {
            canceledBeforeRegistration.insert(id)
            return
        }
        sleeps.remove(at: index).continuation.resume(throwing: CancellationError())
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

actor BikeLiveActivityDeviceSpeedRepository: DeviceSpeedRepository {
    func observeDeviceSpeed() -> AsyncStream<DeviceSpeedSample> { .init { _ in } }
    func locationAuthorizationStatus() -> LocationAuthorizationStatus { .denied }
    func requestLocationAuthorization() {}
}

actor BikeLiveActivityProfileRepository: BikeProfileRepository {
    func loadProfile() -> BikeProfile? { nil }
    func saveProfile(_: BikeProfile) {}
    func clearProfile() {}
}

actor BikeLiveActivityIMURepository: BikeIMURepository {
    func observeIMU() -> AsyncStream<BikeIMUSample> { .init { _ in } }
    func startIMUMonitoring() throws {}
    func stopIMUMonitoring() {}
}

actor BikeLiveActivityMotionCalibrationRepository: VehicleMotionCalibrationRepository {
    func load(vin _: String) -> VehicleMotionCalibration? { nil }
    func save(_: VehicleMotionCalibration) {}
}
