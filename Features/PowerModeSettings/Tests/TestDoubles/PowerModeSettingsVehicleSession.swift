import Foundation
import TestSupport
import VehicleSession

actor PowerModeSettingsVehicleSession: VehicleSessionService {
    private let hub = TestEventHub<VehicleSessionSnapshot>()

    func observe() async -> AsyncStream<VehicleSessionSnapshot> {
        await hub.stream()
    }

    func start() {}
    func stop() {}
    func refreshBikeStatus() {}
    func calibrateDeviceMotion() {}
    func setBatteryHealthMonitoringRequired(_: Bool, consumerID _: UUID) {}

    func send(_ snapshot: VehicleSessionSnapshot) async {
        await hub.waitForSubscriber()
        await hub.send(snapshot)
    }
}
