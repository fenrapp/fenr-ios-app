import BikeDomain
import EnvironmentDomain
import Foundation
import RideSession
import RideSessionDomain
import SettingsDomain
import TestSupport
import VehicleSession

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
    func update(expectedVIN _: String, change _: AppSettingsChange) throws -> AppSettingsUpdateResult {
        throw AppSettingsUpdateError.invalidChange
    }
    func observe() -> AsyncStream<AppSettingsSnapshot> {
        AsyncStream { $0.yield(.init(settings: settings, revision: 0)) }
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
    enum Event: Equatable {
        case save(UUID)
        case complete(UUID)
        case promote(UUID, String)
        case delete(UUID)
    }

    private var active: RideTrip?
    private var deleteSucceeds = true
    private var deletedTripIDs: [UUID] = []
    private var recordedEvents: [Event] = []
    private var completed: [RideTrip] = []
    private var shouldBlockNextPreparation = false
    private var shouldBlockNextCompletion = false
    private var shouldBlockNextPromotion = false
    private var preparationContinuation: CheckedContinuation<Void, Never>?
    private var completionContinuation: CheckedContinuation<Void, Never>?
    private var promotionContinuation: CheckedContinuation<Void, Never>?

    func prepare(context _: BikeSessionContext) async -> RideTrip? {
        if shouldBlockNextPreparation {
            shouldBlockNextPreparation = false
            await withCheckedContinuation { preparationContinuation = $0 }
        }
        return active
    }
    func saveActiveTrip(_ trip: RideTrip) -> Bool {
        active = trip
        recordedEvents.append(.save(trip.id))
        return true
    }
    func completeTrip(_ trip: RideTrip, at date: Date) async -> Bool {
        recordedEvents.append(.complete(trip.id))
        if shouldBlockNextCompletion {
            shouldBlockNextCompletion = false
            await withCheckedContinuation { completionContinuation = $0 }
        }
        let completedTrip = trip.completed(at: date)
        active = nil
        completed.append(completedTrip)
        return true
    }
    func loadCompletedTrips(vin _: String) throws -> [RideTrip] { [] }
    func deleteCompletedTrip(id: UUID, vin _: String) -> Bool {
        deletedTripIDs.append(id)
        recordedEvents.append(.delete(id))
        return deleteSucceeds
    }
    func promoteTemporaryIdentity(_ temporaryID: UUID, toVIN vin: String) async -> Bool {
        recordedEvents.append(.promote(temporaryID, vin))
        if shouldBlockNextPromotion {
            shouldBlockNextPromotion = false
            await withCheckedContinuation { promotionContinuation = $0 }
        }
        return true
    }
    func activeTrip() -> RideTrip? { active }
    func completedTrips() -> [RideTrip] { completed }
    func events() -> [Event] { recordedEvents }
    func saveCount() -> Int {
        recordedEvents.count { if case .save = $0 { true } else { false } }
    }
    func completionCount() -> Int {
        recordedEvents.count { if case .complete = $0 { true } else { false } }
    }
    func setDeleteSucceeds(_ succeeds: Bool) { deleteSucceeds = succeeds }
    func deletedIDs() -> [UUID] { deletedTripIDs }

    func blockNextPreparation() { shouldBlockNextPreparation = true }
    func hasBlockedPreparation() -> Bool { preparationContinuation != nil }
    func resumePreparation() {
        preparationContinuation?.resume()
        preparationContinuation = nil
    }

    func blockNextCompletion() { shouldBlockNextCompletion = true }
    func hasBlockedCompletion() -> Bool { completionContinuation != nil }
    func resumeCompletion() {
        completionContinuation?.resume()
        completionContinuation = nil
    }

    func blockNextPromotion() { shouldBlockNextPromotion = true }
    func hasBlockedPromotion() -> Bool { promotionContinuation != nil }
    func resumePromotion() {
        promotionContinuation?.resume()
        promotionContinuation = nil
    }
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
        case promote(UUID, String)
        case delete(UUID)
    }

    private var recordedEvents: [Event] = []
    private var shouldBlockNextSave = false
    private var shouldBlockNextPromotion = false
    private var blockedSaveContinuation: CheckedContinuation<Void, Never>?
    private var blockedSaveStartedContinuation: CheckedContinuation<Void, Never>?
    private var blockedPromotionContinuation: CheckedContinuation<Void, Never>?
    private var blockedPromotionStartedContinuation: CheckedContinuation<Void, Never>?
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

    func loadCompletedTrips(vin _: String) throws -> [RideTrip] { [] }
    func deleteCompletedTrip(id: UUID, vin _: String) -> Bool {
        recordedEvents.append(.delete(id))
        return true
    }
    func promoteTemporaryIdentity(_ temporaryID: UUID, toVIN vin: String) async -> Bool {
        recordedEvents.append(.promote(temporaryID, vin))
        if shouldBlockNextPromotion {
            shouldBlockNextPromotion = false
            blockedPromotionStartedContinuation?.resume()
            blockedPromotionStartedContinuation = nil
            await withCheckedContinuation { continuation in
                blockedPromotionContinuation = continuation
            }
        }
        return true
    }

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

    func blockNextPromotion() {
        shouldBlockNextPromotion = true
    }

    func waitForBlockedPromotion() async {
        guard blockedPromotionContinuation == nil else { return }
        await withCheckedContinuation { continuation in
            blockedPromotionStartedContinuation = continuation
        }
    }

    func releaseBlockedPromotion() {
        blockedPromotionContinuation?.resume()
        blockedPromotionContinuation = nil
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

actor SessionVehicleSessionService: VehicleSessionService {
    private var snapshot = VehicleSessionSnapshot()
    private var continuations: [UUID: AsyncStream<VehicleSessionSnapshot>.Continuation] = [:]
    private var subscriptions = 0
    private var starts = 0
    private var stops = 0
    private var locationConsumers: Set<UUID> = []
    private var locationRequests: [Bool] = []
    private var blocksNextLocationAcquisition = false
    private var locationContinuation: CheckedContinuation<Void, Never>?

    func observe() -> AsyncStream<VehicleSessionSnapshot> {
        subscriptions += 1
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let id = UUID()
            continuations[id] = continuation
            continuation.yield(snapshot)
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id) }
            }
        }
    }

    func start() { starts += 1 }
    func stop() { stops += 1 }
    func refreshBikeStatus() {}
    func zeroBikeAttitude() {}
    func setBatteryHealthMonitoringRequired(_: Bool, consumerID _: UUID) {}
    func setLocationMonitoringRequired(_ required: Bool, consumerID: UUID) async {
        locationRequests.append(required)
        if required { locationConsumers.insert(consumerID) } else { locationConsumers.remove(consumerID) }
        if required, blocksNextLocationAcquisition {
            blocksNextLocationAcquisition = false
            await withCheckedContinuation { locationContinuation = $0 }
        }
    }

    func blockNextLocationAcquisition() { blocksNextLocationAcquisition = true }
    func hasBlockedLocationRequest() -> Bool { locationContinuation != nil }
    func releaseLocationAcquisition() {
        locationContinuation?.resume()
        locationContinuation = nil
    }

    func locationConsumerCount() -> Int { locationConsumers.count }
    func recordedLocationRequests() -> [Bool] { locationRequests }

    func send(_ snapshot: VehicleSessionSnapshot) {
        self.snapshot = snapshot
        continuations.values.forEach { $0.yield(snapshot) }
    }

    func subscriptionCounts() -> (total: Int, active: Int) {
        (subscriptions, continuations.count)
    }

    private func removeContinuation(_ id: UUID) {
        continuations[id] = nil
    }
}

actor SessionSleepController {
    private let ignoresCancellation: Bool
    private var requestedDurations: [Duration] = []
    private var waiters: [UUID: CheckedContinuation<Void, any Error>] = [:]
    private var cancelledIdentifiers: Set<UUID> = []

    init(ignoresCancellation: Bool = false) {
        self.ignoresCancellation = ignoresCancellation
    }

    func sleep(for duration: Duration) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                requestedDurations.append(duration)
                if cancelledIdentifiers.remove(id) != nil, !ignoresCancellation {
                    continuation.resume(throwing: CancellationError())
                } else {
                    waiters[id] = continuation
                }
            }
        } onCancel: {
            Task { await self.cancel(id) }
        }
    }

    func hasPendingSleep() -> Bool { !waiters.isEmpty }
    func durations() -> [Duration] { requestedDurations }

    func resumeAll() {
        let continuations = Array(waiters.values)
        waiters.removeAll()
        continuations.forEach { $0.resume() }
    }

    private func cancel(_ id: UUID) {
        guard !ignoresCancellation else { return }
        guard let continuation = waiters.removeValue(forKey: id) else {
            cancelledIdentifiers.insert(id)
            return
        }
        continuation.resume(throwing: CancellationError())
    }
}

actor SessionCompletionProbe {
    private var completions = 0

    func complete() { completions += 1 }
    func count() -> Int { completions }
}

actor SessionCallProbe {
    private var calls = 0

    func recordCall() { calls += 1 }
    func count() -> Int { calls }
}
