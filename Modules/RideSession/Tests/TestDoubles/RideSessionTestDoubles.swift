import BikeDomain
import EnvironmentDomain
import Foundation
import RideSession
import RideSessionDomain
import SettingsDomain
import TestSupport

actor SessionBatteryHealthRepository: BikeBatteryHealthRepository {
    func startBatteryHealthMonitoring() async throws {}
    func stopBatteryHealthMonitoring() async {}
    func observeBatteryHealth() async -> AsyncStream<BikeBatteryHealth> { .init { _ in } }
    func observeBatteryDatasetCaptures() async -> AsyncStream<BatteryDatasetCapture> { .init { _ in } }
}

actor SessionBikeRepository: BikeRepository {
    private let telemetryHub = TestEventHub<BikeTelemetry>(bufferingPolicy: .unbounded)
    private let connectionHub = TestEventHub<BikeConnection>(bufferingPolicy: .unbounded)

    func start() {}
    func stop() {}
    func connect(vin _: String) throws {}
    func disconnect() throws {}
    func retrySecurityHandshake() throws {}
    func readTelemetrySnapshot() throws {}
    func observeDebugEvents() -> AsyncStream<BikeDebugEvent> { .init { _ in } }
    func observeTelemetry() async -> AsyncStream<BikeTelemetry> { await telemetryHub.stream() }
    func observeConnection() async -> AsyncStream<BikeConnection> { await connectionHub.stream() }

    func waitForSubscribers() async {
        async let telemetry: Bool = telemetryHub.waitForSubscriber()
        async let connection: Bool = connectionHub.waitForSubscriber()
        _ = await (telemetry, connection)
    }

    func sendTelemetry(_ telemetry: BikeTelemetry) async { await telemetryHub.send(telemetry) }
    func sendConnection(_ connection: BikeConnection) async { await connectionHub.send(connection) }
}

actor SessionSettingsRepository: AppSettingsRepository {
    private let settings: AppSettings

    init(speedSource: SpeedSource) {
        settings = .init(speedSource: speedSource)
    }

    func load() -> AppSettings { settings }
    func save(_: AppSettings) {}
    func observe() -> AsyncStream<AppSettings> {
        AsyncStream { $0.yield(settings) }
    }
}

actor SessionDeviceSpeedRepository: DeviceSpeedRepository {
    private let hub = TestEventHub<DeviceSpeedSample>(bufferingPolicy: .unbounded)

    func observeDeviceSpeed() async -> AsyncStream<DeviceSpeedSample> { await hub.stream() }
    func locationAuthorizationStatus() -> LocationAuthorizationStatus { .authorized }
    func requestLocationAuthorization() {}
    func waitForSubscriber() async { _ = await hub.waitForSubscriber() }
    func send(_ sample: DeviceSpeedSample) async { await hub.send(sample) }
}

actor SessionIMURepository: BikeIMURepository {
    func observeIMU() -> AsyncStream<BikeIMUSample> { .init { _ in } }
    func startIMUMonitoring() throws {}
    func stopIMUMonitoring() {}
}

actor SessionMotionCalibrationRepository: VehicleMotionCalibrationRepository {
    func load(vin _: String) -> VehicleMotionCalibration? { nil }
    func save(_: VehicleMotionCalibration) {}
}

actor SessionProfileRepository: BikeProfileRepository {
    func loadProfile() -> BikeProfile? { .init(vin: "TESTVIN0000000001") }
    func saveProfile(_: BikeProfile) {}
    func clearProfile() {}
}

actor SessionTripRepository: RideTripRepository {
    private var active: RideTrip?
    private var deleteSucceeds = true
    private var deletedTripIDs: [UUID] = []

    func prepare(context _: BikeSessionContext) -> RideTrip? { active }
    func saveActiveTrip(_ trip: RideTrip) -> Bool {
        active = trip
        return true
    }
    func completeTrip(_ trip: RideTrip, at date: Date) -> Bool {
        active = trip.completed(at: date)
        return true
    }
    func loadCompletedTrips(vin _: String) -> [RideTrip] { [] }
    func deleteCompletedTrip(id: UUID, vin _: String) -> Bool {
        deletedTripIDs.append(id)
        return deleteSucceeds
    }
    func promoteTemporaryIdentity(_: UUID, toVIN _: String) -> Bool { true }
    func activeTrip() -> RideTrip? { active }
    func setDeleteSucceeds(_ succeeds: Bool) { deleteSucceeds = succeeds }
    func deletedIDs() -> [UUID] { deletedTripIDs }
}

struct SessionIdentityResolver: RideVehicleIdentityResolving {
    func confirmedVIN(from candidate: String) -> String? {
        candidate.isEmpty ? nil : candidate
    }
}

actor BlockingRideTripRepository: RideTripRepository {
    enum Event: Equatable {
        case save(UUID)
        case reset(UUID, UUID?)
        case delete(UUID)
    }

    private var recordedEvents: [Event] = []
    private var shouldBlockNextSave = false
    private var blockedSaveContinuation: CheckedContinuation<Void, Never>?
    private var blockedSaveStartedContinuation: CheckedContinuation<Void, Never>?
    private var activeWrites = 0
    private var maximumActiveWrites = 0

    func prepare(context _: BikeSessionContext) -> RideTrip? { nil }

    func saveActiveTrip(_ trip: RideTrip) async -> Bool {
        activeWrites += 1
        maximumActiveWrites = max(maximumActiveWrites, activeWrites)
        recordedEvents.append(.save(trip.id))
        if shouldBlockNextSave {
            shouldBlockNextSave = false
            blockedSaveStartedContinuation?.resume()
            blockedSaveStartedContinuation = nil
            await withCheckedContinuation { continuation in
                blockedSaveContinuation = continuation
            }
        }
        activeWrites -= 1
        return true
    }

    func completeTrip(_: RideTrip, at _: Date) -> Bool { true }

    func resetTrip(completing trip: RideTrip, starting replacement: RideTrip?, at _: Date) -> Bool {
        recordedEvents.append(.reset(trip.id, replacement?.id))
        return true
    }

    func loadCompletedTrips(vin _: String) -> [RideTrip] { [] }
    func deleteCompletedTrip(id: UUID, vin _: String) -> Bool {
        recordedEvents.append(.delete(id))
        return true
    }
    func promoteTemporaryIdentity(_: UUID, toVIN _: String) -> Bool { true }

    func blockNextSave() {
        shouldBlockNextSave = true
    }

    func waitForBlockedSave() async {
        guard blockedSaveContinuation == nil else { return }
        await withCheckedContinuation { continuation in
            blockedSaveStartedContinuation = continuation
        }
    }

    func releaseBlockedSave() {
        blockedSaveContinuation?.resume()
        blockedSaveContinuation = nil
    }

    func savedTripIDs() -> [UUID] {
        recordedEvents.compactMap {
            guard case .save(let id) = $0 else { return nil }
            return id
        }
    }

    func events() -> [Event] { recordedEvents }
    func maximumConcurrentWrites() -> Int { maximumActiveWrites }
}
