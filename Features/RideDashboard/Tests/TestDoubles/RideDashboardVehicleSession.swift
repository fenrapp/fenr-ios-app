import Foundation
import TestSupport
import VehicleSession

actor RideDashboardVehicleSession: VehicleSessionService {
    private let hub = TestEventHub<VehicleSessionSnapshot>(bufferingPolicy: .unbounded)
    private var refreshCount = 0
    private var batteryHealthMonitoringRequests: [Bool] = []
    private var currentSnapshot = VehicleSessionSnapshot()
    private var observationCount = 0

    func observe() async -> AsyncStream<VehicleSessionSnapshot> {
        observationCount += 1
        return await hub.stream(replay: currentSnapshot)
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
        currentSnapshot = snapshot
        _ = await hub.waitForSubscriber()
        await hub.send(snapshot)
    }

    func statusRefreshCount() -> Int {
        refreshCount
    }

    func recordedBatteryHealthMonitoringRequests() -> [Bool] {
        batteryHealthMonitoringRequests
    }

    func recordedObservationCount() -> Int {
        observationCount
    }
}
