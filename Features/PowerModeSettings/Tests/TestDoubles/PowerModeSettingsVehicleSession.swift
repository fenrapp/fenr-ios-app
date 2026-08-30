import Foundation
import TestSupport
import VehicleSession

actor PowerModeSettingsVehicleSession: VehicleSessionService {
    private let hub = TestEventHub<VehicleSessionSnapshot>(bufferingPolicy: .unbounded)

    func observe() async -> AsyncStream<VehicleSessionSnapshot> {
        await hub.stream()
    }

    func start() {}
    func stop() {}
    func refreshBikeStatus() {}
    func zeroBikeAttitude() {}
    func setBatteryHealthMonitoringRequired(_: Bool, consumerID _: UUID) {}

    func send(_ snapshot: VehicleSessionSnapshot) async {
        _ = await hub.waitForSubscriber()
        await hub.send(snapshot)
    }
}
