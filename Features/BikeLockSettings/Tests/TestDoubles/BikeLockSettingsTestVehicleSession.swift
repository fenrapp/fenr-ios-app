import Foundation
import TestSupport
import VehicleSession

actor BikeLockSettingsTestVehicleSession: VehicleSessionService {
    private let hub = TestEventHub<VehicleSessionSnapshot>(bufferingPolicy: .bufferingNewest(1))

    private var snapshot: VehicleSessionSnapshot?

    func observe() async -> AsyncStream<VehicleSessionSnapshot> { await hub.stream(replay: snapshot) }
    func start() {}
    func stop() {}
    func refreshBikeStatus() {}
    func zeroBikeAttitude() {}
    func setBatteryHealthMonitoringRequired(_: Bool, consumerID _: UUID) {}

    func send(_ snapshot: VehicleSessionSnapshot) async {
        self.snapshot = snapshot
        await hub.send(snapshot)
    }
}
