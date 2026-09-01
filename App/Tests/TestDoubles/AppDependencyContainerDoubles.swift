import BikeDomain
import Foundation
import RideSession
import SettingsDomain
import VehicleSession

actor EmptyBikeProfileRepository: BikeProfileRepository {
    func loadProfile() -> BikeProfile? {
        nil
    }

    func saveProfile(_: BikeProfile) {}

    func clearProfile() {}
}

actor EmptyAppSettingsRepository: AppSettingsRepository {
    func load() async -> AppSettings { .init() }
    func save(_: AppSettings) async {}
    func observe() async -> AsyncStream<AppSettings> {
        AsyncStream { continuation in
            continuation.yield(.init())
        }
    }
}

actor LifecycleVehicleSessionSpy: VehicleSessionService {
    private var starts = 0
    private var stops = 0
    private var batteryHealthRequirements: [Bool] = []

    func observe() -> AsyncStream<VehicleSessionSnapshot> {
        AsyncStream { continuation in
            continuation.yield(.init())
        }
    }

    func start() { starts += 1 }
    func stop() { stops += 1 }
    func refreshBikeStatus() {}
    func zeroBikeAttitude() {}

    func setBatteryHealthMonitoringRequired(_ required: Bool, consumerID _: UUID) {
        batteryHealthRequirements.append(required)
    }

    func startCount() -> Int { starts }
    func stopCount() -> Int { stops }
    func requirements() -> [Bool] { batteryHealthRequirements }
}

actor LifecycleRideSessionSpy: RideSessionService {
    private var events: [String] = []
    private var delaysPersistence = false
    private var persistenceContinuation: CheckedContinuation<Void, Never>?

    func observe() -> AsyncStream<RideSessionSnapshot> { .init { _ in } }
    func start() { events.append("start") }
    func stop() { events.append("stop") }

    func persistCurrentTrip() async {
        if delaysPersistence {
            delaysPersistence = false
            await withCheckedContinuation { continuation in
                persistenceContinuation = continuation
            }
        }
        events.append("persist")
    }

    func completeCurrentTrip() { events.append("complete") }
    func flush() { events.append("flush") }
    func togglePauseCurrentTrip() {}
    func resetCurrentTrip() {}

    func delayNextPersistence() { delaysPersistence = true }
    func hasPendingPersistence() -> Bool { persistenceContinuation != nil }
    func resumePersistence() {
        persistenceContinuation?.resume()
        persistenceContinuation = nil
    }
    func recordedEvents() -> [String] { events }
}

actor ControllableAppStartupPreparer: AppStartupPreparing {
    private var prepares = 0
    private var shouldBlock = false
    private var continuation: CheckedContinuation<Void, Never>?

    func prepare() async {
        prepares += 1
        guard shouldBlock else { return }
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func blockNextPreparation() {
        shouldBlock = true
    }

    func preparationCount() -> Int { prepares }
    func hasPendingPreparation() -> Bool { continuation != nil }

    func resumePreparation() {
        shouldBlock = false
        continuation?.resume()
        continuation = nil
    }
}
