import Foundation
import TestSupport
import VehicleSession

actor MaintenanceTestVehicleSession: VehicleSessionService {
    private let hub = TestEventHub<VehicleSessionSnapshot>(bufferingPolicy: .unbounded)
    private var snapshot: VehicleSessionSnapshot

    init(snapshot: VehicleSessionSnapshot) {
        self.snapshot = snapshot
    }

    func observe() async -> AsyncStream<VehicleSessionSnapshot> {
        await hub.stream(replay: snapshot)
    }

    func start() async {}
    func stop() async {}
    func refreshBikeStatus() async {}
    func zeroBikeAttitude() async {}
    func setBatteryHealthMonitoringRequired(_: Bool, consumerID _: UUID) async {}

    func send(_ snapshot: VehicleSessionSnapshot) async {
        self.snapshot = snapshot
        await hub.send(snapshot)
    }

    func waitForSubscriber() async {
        _ = await hub.waitForSubscriber()
    }
}
