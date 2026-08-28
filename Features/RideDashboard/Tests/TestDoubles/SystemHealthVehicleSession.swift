import Foundation
import TestSupport
import VehicleSession

actor SystemHealthVehicleSession: VehicleSessionService {
    private let hub = TestEventHub<VehicleSessionSnapshot>()
    private var monitoringRequirements: [Bool] = []

    func observe() async -> AsyncStream<VehicleSessionSnapshot> {
        await hub.stream()
    }

    func start() {}
    func stop() {}
    func refreshBikeStatus() {}
    func calibrateDeviceMotion() {}

    func setBatteryHealthMonitoringRequired(_ required: Bool, consumerID _: UUID) {
        monitoringRequirements.append(required)
    }

    func send(_ snapshot: VehicleSessionSnapshot, waitsForSubscriber: Bool = true) async {
        if waitsForSubscriber {
            await hub.waitForSubscriber()
        }
        await hub.send(snapshot)
    }

    func requirements() -> [Bool] {
        monitoringRequirements
    }
}
