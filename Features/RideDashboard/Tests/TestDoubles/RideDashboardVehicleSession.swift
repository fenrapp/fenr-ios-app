import Foundation
import TestSupport
import VehicleSession

actor RideDashboardVehicleSession: VehicleSessionService {
    private let hub = TestEventHub<VehicleSessionSnapshot>()
    private var refreshCount = 0
    private var batteryHealthMonitoringRequests: [Bool] = []

    func observe() async -> AsyncStream<VehicleSessionSnapshot> {
        await hub.stream()
    }

    func start() {}
    func stop() {}

    func refreshBikeStatus() {
        refreshCount += 1
    }
    func zeroBikeAttitude() {}

    func setBatteryHealthMonitoringRequired(_ required: Bool, consumerID _: UUID) {
        batteryHealthMonitoringRequests.append(required)
    }

    func send(_ snapshot: VehicleSessionSnapshot) async {
        await hub.waitForSubscriber()
        await hub.send(snapshot)
    }

    func statusRefreshCount() -> Int {
        refreshCount
    }

    func recordedBatteryHealthMonitoringRequests() -> [Bool] {
        batteryHealthMonitoringRequests
    }
}
