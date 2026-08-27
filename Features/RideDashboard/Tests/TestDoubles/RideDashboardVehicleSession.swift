import Foundation
import TestSupport
import VehicleSession

actor RideDashboardVehicleSession: VehicleSessionService {
    private let hub = TestEventHub<VehicleSessionSnapshot>()
    private var refreshCount = 0

    func observe() async -> AsyncStream<VehicleSessionSnapshot> {
        await hub.stream()
    }

    func start() {}
    func stop() {}

    func refreshBikeStatus() {
        refreshCount += 1
    }
    func calibrateDeviceMotion() {}

    func setBatteryHealthMonitoringRequired(_: Bool, consumerID _: UUID) {}

    func send(_ snapshot: VehicleSessionSnapshot) async {
        await hub.waitForSubscriber()
        await hub.send(snapshot)
    }

    func statusRefreshCount() -> Int {
        refreshCount
    }
}
