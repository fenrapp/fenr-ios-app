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
    private var shouldFailNextStart = false
    private var shouldDelayNextStart = false
    private var startWaiter: CheckedContinuation<Void, Never>?

    func start() {}
    func stop() {}
    func connect(vin _: String) throws {}
    func disconnect() throws {}
    func retrySecurityHandshake() throws {}
    func readTelemetrySnapshot() throws {}
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

    func stopBatteryHealthMonitoring() {
        monitoringStops += 1
    }

    func observeBatteryHealth() async -> AsyncStream<BikeBatteryHealth> {
        await healthHub.stream()
    }

    func observeBatteryDatasetCaptures() -> AsyncStream<BatteryDatasetCapture> { .init { _ in } }

    func sendTelemetry(_ value: BikeTelemetry) async { await telemetryHub.send(value) }
    func sendConnection(_ value: BikeConnection) async { await connectionHub.send(value) }
    func sendHealth(_ value: BikeBatteryHealth) async { await healthHub.send(value) }
    func sourceSubscriptionCounts() -> (Int, Int) { (telemetrySubscriptions, connectionSubscriptions) }
    func monitoringCounts() -> (Int, Int) { (monitoringStarts, monitoringStops) }
    func failNextStart() { shouldFailNextStart = true }
    func delayNextStart() { shouldDelayNextStart = true }
    func hasPendingStart() -> Bool { startWaiter != nil }

    func resumeStart() {
        let waiter = startWaiter
        startWaiter = nil
        waiter?.resume()
    }
}

actor VehicleSessionTestSettingsRepository: AppSettingsRepository {
    private let settings: AppSettings
    private var subscriptions = 0

    init(speedSource: SpeedSource = .motorcycle) {
        settings = .init(speedSource: speedSource)
    }

    func load() -> AppSettings { settings }
    func save(_: AppSettings) {}
    func observe() -> AsyncStream<AppSettings> {
        subscriptions += 1
        return .init { $0.yield(settings) }
    }
    func subscriptionCount() -> Int { subscriptions }
}

actor VehicleSessionTestProfileRepository: BikeProfileRepository {
    private var subscriptions = 0
    func loadProfile() -> BikeProfile? { .init(vin: "TESTVIN0000000001") }
    func saveProfile(_: BikeProfile) {}
    func clearProfile() {}
    func observeProfile() async -> AsyncStream<BikeProfileState> {
        subscriptions += 1
        return .init { $0.yield(.init(profile: .init(vin: "TESTVIN0000000001"))) }
    }
    func subscriptionCount() -> Int { subscriptions }
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

actor VehicleSessionTestDeviceMotionRepository: DeviceMotionRepository {
    private let hub = VehicleSessionTestHub<DeviceMotionSample>()
    func observeDeviceMotion() async -> AsyncStream<DeviceMotionSample> { await hub.stream() }
    func send(_ value: DeviceMotionSample) async { await hub.send(value) }
}

actor VehicleSessionTestMotionCalibrationRepository: VehicleMotionCalibrationRepository {
    private var value: VehicleMotionCalibration?
    func load(vin _: String) -> VehicleMotionCalibration? { value }
    func save(_ calibration: VehicleMotionCalibration) { value = calibration }
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

    private func remove(_ id: UUID) { continuations[id] = nil }
}

enum VehicleSessionTestError: Error {
    case startFailed
}
