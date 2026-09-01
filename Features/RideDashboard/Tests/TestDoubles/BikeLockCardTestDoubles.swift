import BikeDomain
import Foundation
@testable import RideDashboard
import SettingsDomain

actor BikeLockCardRepository: BikeRepository {
    private var lockState: Bool
    private var prepareRequests = 0
    private var lockRequests: [Bool] = []

    init(isLocked: Bool = false) {
        lockState = isLocked
    }

    func start() {}
    func stop() {}
    func connect(vin _: String) throws {}
    func disconnect() throws {}
    func retrySecurityHandshake() throws {}
    func readTelemetrySnapshot() throws {}

    func prepareBikeLockControl() throws -> BikeLockControlSnapshot {
        prepareRequests += 1
        return snapshot()
    }

    func setBikeLocked(_ isLocked: Bool) -> BikeLockControlSnapshot {
        lockRequests.append(isLocked)
        lockState = isLocked
        return snapshot()
    }

    func observeTelemetry() -> AsyncStream<BikeTelemetry> { .init { $0.finish() } }
    func observeConnection() -> AsyncStream<BikeConnection> { .init { $0.finish() } }
    func observeDebugEvents() -> AsyncStream<BikeDebugEvent> { .init { $0.finish() } }

    func recordedPrepareRequests() -> Int { prepareRequests }
    func recordedLockRequests() -> [Bool] { lockRequests }

    private func snapshot() -> BikeLockControlSnapshot {
        .init(vcuFirmware: "1.6.29", isLocked: lockState, didPassNoOpWrite: true)
    }
}

actor BikeLockCardSettingsRepository: AppSettingsRepository {
    private var settings: AppSettings

    init(settings: AppSettings = .init()) {
        self.settings = settings
    }

    func load() -> AppSettings { settings }
    func save(_ settings: AppSettings) { self.settings = settings }
    func observe() -> AsyncStream<AppSettings> { .init { $0.finish() } }
}

actor BikeLockCardCredentialStore: BikeLockCredentialStoring {
    private var pins: [String: String] = [:]

    func save(pin: String, for vehicleIdentifier: String) {
        pins[vehicleIdentifier] = pin
    }

    func verify(pin: String, for vehicleIdentifier: String) -> Bool {
        pins[vehicleIdentifier] == pin
    }

    func containsPIN(for vehicleIdentifier: String) -> Bool {
        pins[vehicleIdentifier] != nil
    }

    func removePIN(for vehicleIdentifier: String) {
        pins[vehicleIdentifier] = nil
    }

    func storedPIN(for vehicleIdentifier: String) -> String? {
        pins[vehicleIdentifier]
    }
}

actor BikeLockCardAuthenticator: BikeLockAuthenticating {
    private let result: Bool

    init(result: Bool = true) {
        self.result = result
    }

    func authenticate(reason _: String) -> Bool { result }
}

actor SuspendedBikeLockCardAuthenticator: BikeLockAuthenticating {
    private var continuation: CheckedContinuation<Bool, any Error>?
    private var cancellationCount = 0

    func authenticate(reason _: String) async throws -> Bool {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
            }
        } onCancel: {
            Task { await self.cancel() }
        }
    }

    func hasPendingAuthentication() -> Bool {
        continuation != nil
    }

    func recordedCancellationCount() -> Int {
        cancellationCount
    }

    private func cancel() {
        guard let continuation else { return }
        self.continuation = nil
        cancellationCount += 1
        continuation.resume(throwing: CancellationError())
    }
}

@MainActor
final class BikeLockCardCapabilityStore: BikeLockCapabilityStateStoring {
    private(set) var currentState = BikeLockCapabilityState()

    func update(_ state: BikeLockCapabilityState) {
        currentState = state
    }

    func observe() -> AsyncStream<BikeLockCapabilityState> {
        .init { continuation in
            continuation.yield(currentState)
            continuation.finish()
        }
    }
}
