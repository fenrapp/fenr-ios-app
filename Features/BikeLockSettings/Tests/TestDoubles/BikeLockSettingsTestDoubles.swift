import BikeDomain
import Foundation
import SettingsDomain
import TestSupport
import VehicleSession

actor BikeLockSettingsTestVehicleSession: VehicleSessionService {
    private let hub = TestEventHub<VehicleSessionSnapshot>()

    func observe() async -> AsyncStream<VehicleSessionSnapshot> { await hub.stream() }
    func start() {}
    func stop() {}
    func refreshBikeStatus() {}
    func zeroBikeAttitude() {}
    func setBatteryHealthMonitoringRequired(_: Bool, consumerID _: UUID) {}

    func send(_ snapshot: VehicleSessionSnapshot) async {
        await hub.waitForSubscriber()
        await hub.send(snapshot)
    }
}

@MainActor
final class BikeLockSettingsTestCapabilityStore: BikeLockCapabilityStateStoring {
    private(set) var currentState: BikeLockCapabilityState

    init(state: BikeLockCapabilityState) { currentState = state }
    func update(_ state: BikeLockCapabilityState) { currentState = state }
    func observe() -> AsyncStream<BikeLockCapabilityState> { .init { $0.yield(currentState) } }
}

actor BikeLockSettingsTestRepository: AppSettingsRepository {
    private var settings: AppSettings
    init(settings: AppSettings) { self.settings = settings }
    func load() -> AppSettings { settings }
    func save(_ settings: AppSettings) { self.settings = settings }
    func observe() -> AsyncStream<AppSettings> { .init { $0.finish() } }
}

actor BikeLockSettingsTestCredentialStore: BikeLockCredentialStoring {
    private var pins: [String: String]
    init(vin: String, pin: String? = nil) { pins = pin.map { [vin: $0] } ?? [:] }
    func save(pin: String, for vehicleIdentifier: String) { pins[vehicleIdentifier] = pin }
    func verify(pin: String, for vehicleIdentifier: String) -> Bool { pins[vehicleIdentifier] == pin }
    func containsPIN(for vehicleIdentifier: String) -> Bool { pins[vehicleIdentifier] != nil }
    func removePIN(for vehicleIdentifier: String) { pins[vehicleIdentifier] = nil }
    func storedPIN(for vehicleIdentifier: String) -> String? { pins[vehicleIdentifier] }
}

struct BikeLockSettingsTestAuthenticator: BikeLockAuthenticating {
    let result: Bool
    func authenticate(reason _: String) async throws -> Bool { result }
}
