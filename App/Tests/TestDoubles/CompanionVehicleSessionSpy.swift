import Foundation
import TestSupport
import VehicleSession

actor CompanionVehicleSessionSpy: VehicleSessionService {
    private let hub: TestEventHub<VehicleSessionSnapshot>
    private var holdRelease = false
    private var releaseContinuation: CheckedContinuation<Void, Never>?
    private var monitoring: Set<UUID> = []

    init(hub: TestEventHub<VehicleSessionSnapshot>) { self.hub = hub }
    func observe() async -> AsyncStream<VehicleSessionSnapshot> { await hub.stream() }
    func start() async {}
    func stop() async {}
    func refreshBikeStatus() async {}
    func zeroBikeAttitude() async {}
    func setBatteryHealthMonitoringRequired(_ required: Bool, consumerID: UUID) async {
        if !required, holdRelease {
            await withCheckedContinuation { releaseContinuation = $0 }
        }
        if required { monitoring.insert(consumerID) } else { monitoring.remove(consumerID) }
    }
    func isMonitoring() -> Bool { !monitoring.isEmpty }
    func pauseRelease() { holdRelease = true }
    func hasPendingRelease() -> Bool { releaseContinuation != nil }
    func resumeRelease() {
        holdRelease = false
        releaseContinuation?.resume()
        releaseContinuation = nil
    }

}
