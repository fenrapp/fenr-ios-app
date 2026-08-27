import Foundation
import TestSupport
import VehicleSession

actor ChargingDashboardVehicleSession: VehicleSessionService {
    private let hub = TestEventHub<VehicleSessionSnapshot>()
    private var monitoringRequirements: [Bool] = []
    private var startedMonitoringRequirements: [Bool] = []
    private let monitoringEnableDelay: Duration

    init(monitoringEnableDelay: Duration = .zero) {
        self.monitoringEnableDelay = monitoringEnableDelay
    }

    func observe() async -> AsyncStream<VehicleSessionSnapshot> {
        await hub.stream()
    }

    func start() {}
    func stop() {}
    func refreshBikeStatus() {}
    func calibrateDeviceMotion() {}

    func setBatteryHealthMonitoringRequired(_ required: Bool, consumerID _: UUID) async {
        startedMonitoringRequirements.append(required)
        if required, monitoringEnableDelay > .zero {
            try? await Task.sleep(for: monitoringEnableDelay)
        }
        monitoringRequirements.append(required)
    }

    func send(_ snapshot: VehicleSessionSnapshot) async {
        await hub.waitForSubscriber()
        await hub.send(snapshot)
    }

    func requirements() -> [Bool] {
        monitoringRequirements
    }

    func startedRequirements() -> [Bool] {
        startedMonitoringRequirements
    }
}
