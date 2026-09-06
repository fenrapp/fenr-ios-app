import BikeDomain
import EnvironmentDomain
import Foundation
import SettingsDomain
import VehicleSession

actor VehicleSessionTestRepository: BikeRepository, BikeBatteryHealthRepository {
    private let telemetryHub = VehicleSessionTestHub<BikeTelemetry>()
    private let connectionHub = VehicleSessionTestHub<BikeConnection>()
    private let healthHub = VehicleSessionTestHub<BikeBatteryHealth>()
    private var telemetrySubscriptions = 0
    private var connectionSubscriptions = 0
    private var monitoringStarts = 0
    private var monitoringStops = 0
    private var refreshedPowerModeIndexes: [Int] = []
    private var refreshedTractionControlIndexes: [Int] = []
    private var shouldFailNextStart = false
    private var shouldDelayNextStart = false
    private var shouldDelayNextStop = false
    private var startWaiter: CheckedContinuation<Void, Never>?
    private var stopWaiter: CheckedContinuation<Void, Never>?
    private var suspendedPowerModeRefreshIndexes: Set<Int> = []
    private var powerModeRefreshWaiters: [Int: [CheckedContinuation<Void, Never>]] = [:]

    func start() {}
    func stop() {}
    func connect(vin _: String) throws {}
    func disconnect() throws {}
    func retrySecurityHandshake() throws {}
    func readTelemetrySnapshot() throws {}
    func refreshPowerModeConfiguration(mapIndex: Int) async {
        refreshedPowerModeIndexes.append(mapIndex)
        guard suspendedPowerModeRefreshIndexes.contains(mapIndex) else { return }
        await withCheckedContinuation { continuation in
            powerModeRefreshWaiters[mapIndex, default: []].append(continuation)
        }
    }
    func refreshTractionControlConfiguration(mapIndex: Int) {
        refreshedTractionControlIndexes.append(mapIndex)
    }
    func observeDebugEvents() -> AsyncStream<BikeDebugEvent> { .init { _ in } }

    func observeTelemetry() async -> AsyncStream<BikeTelemetry> {
        telemetrySubscriptions += 1
        return await telemetryHub.stream()
    }

    func observeConnection() async -> AsyncStream<BikeConnection> {
        connectionSubscriptions += 1
        return await connectionHub.stream()
    }

    func startBatteryHealthMonitoring() async throws {
        monitoringStarts += 1
        if shouldFailNextStart {
            shouldFailNextStart = false
            throw VehicleSessionTestError.startFailed
        }
        if shouldDelayNextStart {
            shouldDelayNextStart = false
            await withCheckedContinuation { startWaiter = $0 }
        }
    }

    func stopBatteryHealthMonitoring() async {
        monitoringStops += 1
        guard shouldDelayNextStop else { return }
        shouldDelayNextStop = false
        await withCheckedContinuation { stopWaiter = $0 }
    }

    func observeBatteryHealth() async -> AsyncStream<BikeBatteryHealth> {
        await healthHub.stream()
    }

    func observeBatteryDatasetCaptures() -> AsyncStream<BatteryDatasetCapture> { .init { _ in } }

    func sendTelemetry(_ value: BikeTelemetry) async { await telemetryHub.send(value) }
    func sendConnection(_ value: BikeConnection) async { await connectionHub.send(value) }
    func sendHealth(_ value: BikeBatteryHealth) async { await healthHub.send(value) }
    func sourceSubscriptionCounts() -> (Int, Int) { (telemetrySubscriptions, connectionSubscriptions) }
    func activeSourceSubscriptionCounts() async -> (Int, Int) {
        await (telemetryHub.subscriberCount(), connectionHub.subscriberCount())
    }
    func monitoringCounts() -> (Int, Int) { (monitoringStarts, monitoringStops) }
    func activeHealthSubscriptionCount() async -> Int { await healthHub.subscriberCount() }
    func powerModeRefreshes() -> (base: [Int], traction: [Int]) {
        (refreshedPowerModeIndexes, refreshedTractionControlIndexes)
    }
    func suspendPowerModeRefresh(mapIndex: Int) {
        suspendedPowerModeRefreshIndexes.insert(mapIndex)
    }
    func hasPendingPowerModeRefresh(mapIndex: Int) -> Bool {
        powerModeRefreshWaiters[mapIndex]?.isEmpty == false
    }
    func resumePowerModeRefresh(mapIndex: Int) {
        suspendedPowerModeRefreshIndexes.remove(mapIndex)
        let waiters = powerModeRefreshWaiters.removeValue(forKey: mapIndex) ?? []
        waiters.forEach { $0.resume() }
    }
    func failNextStart() { shouldFailNextStart = true }
    func delayNextStart() { shouldDelayNextStart = true }
    func delayNextStop() { shouldDelayNextStop = true }
    func hasPendingStart() -> Bool { startWaiter != nil }
    func hasPendingStop() -> Bool { stopWaiter != nil }

    func resumeStart() {
        let waiter = startWaiter
        startWaiter = nil
        waiter?.resume()
    }

    func resumeStop() {
        let waiter = stopWaiter
        stopWaiter = nil
        waiter?.resume()
    }
}

actor VehicleSessionTestSettingsRepository: AppSettingsRepository {
    private let settings: AppSettings
    private var subscriptions = 0
    private var continuations: [UUID: AsyncStream<AppSettings>.Continuation] = [:]

    init(speedSource: SpeedSource = .motorcycle) {
        settings = .init(speedSource: speedSource)
    }

    func load() -> AppSettings { settings }
    func save(_: AppSettings) {}
    func observe() -> AsyncStream<AppSettings> {
        subscriptions += 1
        return .init { continuation in
            let id = UUID()
            continuations[id] = continuation
            continuation.yield(settings)
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id) }
            }
        }
    }
    func subscriptionCount() -> Int { subscriptions }
    func activeSubscriptionCount() -> Int { continuations.count }
    private func removeContinuation(_ id: UUID) { continuations[id] = nil }
}

actor VehicleSessionTestProfileRepository: BikeProfileRepository {
    private var subscriptions = 0
    private var continuations: [UUID: AsyncStream<BikeProfileState>.Continuation] = [:]
    func loadProfile() -> BikeProfile? { .init(vin: "TESTVIN0000000001") }
    func saveProfile(_: BikeProfile) {}
    func clearProfile() {}
    func observeProfile() async -> AsyncStream<BikeProfileState> {
        subscriptions += 1
        return .init { continuation in
            let id = UUID()
            continuations[id] = continuation
            continuation.yield(.init(profile: .init(vin: "TESTVIN0000000001")))
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id) }
            }
        }
    }
    func subscriptionCount() -> Int { subscriptions }
    func activeSubscriptionCount() -> Int { continuations.count }
    private func removeContinuation(_ id: UUID) { continuations[id] = nil }
}

actor VehicleSessionTestDeviceSpeedRepository: DeviceSpeedRepository {
    private let hub = VehicleSessionTestHub<DeviceSpeedSample>()
    private var subscriptions = 0
    func observeDeviceSpeed() async -> AsyncStream<DeviceSpeedSample> {
        subscriptions += 1
        return await hub.stream()
    }
    func locationAuthorizationStatus() -> LocationAuthorizationStatus { .authorized }
    func requestLocationAuthorization() {}
    func send(_ value: DeviceSpeedSample) async { await hub.send(value) }
    func subscriptionCount() -> Int { subscriptions }
}

actor VehicleSessionTestIMURepository: BikeIMURepository {
    private let hub = VehicleSessionTestHub<BikeIMUSample>()
    private var subscriptions = 0
    private var monitoringStarts = 0
    private var monitoringStops = 0
    private var shouldSuspendNextStart = false
    private var startWaiter: CheckedContinuation<Void, Never>?

    func observeIMU() async -> AsyncStream<BikeIMUSample> {
        subscriptions += 1
        return await hub.stream()
    }
    func startIMUMonitoring() async {
        monitoringStarts += 1
        guard shouldSuspendNextStart else { return }
        shouldSuspendNextStart = false
        await withCheckedContinuation { startWaiter = $0 }
    }
    func stopIMUMonitoring() { monitoringStops += 1 }
    func send(_ value: BikeIMUSample) async { await hub.send(value) }
    func subscriptionCount() -> Int { subscriptions }
    func activeSubscriptionCount() async -> Int { await hub.subscriberCount() }
    func monitoringCounts() -> (Int, Int) { (monitoringStarts, monitoringStops) }
    func suspendNextStartIgnoringCancellation() { shouldSuspendNextStart = true }
    func hasPendingStart() -> Bool { startWaiter != nil }
    func resumeStart() {
        let waiter = startWaiter
        startWaiter = nil
        waiter?.resume()
    }
}

actor VehicleSessionTestMotionCalibrationRepository: VehicleMotionCalibrationRepository {
    private var value: VehicleMotionCalibration?
    private var shouldSuspendNextLoad = false
    private var loadWaiter: CheckedContinuation<Void, Never>?

    func load(vin _: String) async -> VehicleMotionCalibration? {
        if shouldSuspendNextLoad {
            shouldSuspendNextLoad = false
            await withCheckedContinuation { loadWaiter = $0 }
        }
        return value
    }

    func save(_ calibration: VehicleMotionCalibration) { value = calibration }
    func savedValue() -> VehicleMotionCalibration? { value }
    func suspendNextLoadIgnoringCancellation() { shouldSuspendNextLoad = true }
    func hasPendingLoad() -> Bool { loadWaiter != nil }

    func resumeLoad() {
        let waiter = loadWaiter
        loadWaiter = nil
        waiter?.resume()
    }
}

private actor VehicleSessionTestHub<Element: Sendable> {
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
        continuations.values.forEach { $0.yield(value) }
    }

    func subscriberCount() -> Int { continuations.count }

    private func remove(_ id: UUID) { continuations[id] = nil }
}

actor VehicleSessionTestSleepRecorder {
    private var durations: [Duration] = []

    func sleep(for duration: Duration) {
        durations.append(duration)
    }

    func recordedDurations() -> [Duration] { durations }
}

enum VehicleSessionTestError: Error {
    case startFailed
}
