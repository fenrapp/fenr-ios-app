import Foundation
import TestSupport
import VehicleSession

actor FakeVehicleSession: VehicleSessionService {
    private let hub = TestEventHub<VehicleSessionSnapshot>(bufferingPolicy: .bufferingNewest(1))
    private var latestSnapshot: VehicleSessionSnapshot
    private(set) var observeCount = 0
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var refreshCount = 0

    init(snapshot: VehicleSessionSnapshot = .init()) {
        latestSnapshot = snapshot
    }

    func observe() async -> AsyncStream<VehicleSessionSnapshot> {
        observeCount += 1
        return await hub.stream(replay: latestSnapshot)
    }

    func start() async { startCount += 1 }
    func stop() async { stopCount += 1 }
    func refreshBikeStatus() async { refreshCount += 1 }
    func zeroBikeAttitude() async {}
    func setBatteryHealthMonitoringRequired(_: Bool, consumerID _: UUID) async {}
    func setLocationMonitoringRequired(_: Bool, consumerID _: UUID) async {}

    func send(_ snapshot: VehicleSessionSnapshot) async {
        latestSnapshot = snapshot
        _ = await hub.waitForSubscriber()
        await hub.send(snapshot)
    }
}
