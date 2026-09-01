import Foundation
import VehicleSession

actor TestVehicleSessionService: VehicleSessionService {
    private var continuations: [UUID: AsyncStream<VehicleSessionSnapshot>.Continuation] = [:]
    private var subscriberWaiters: [CheckedContinuation<Void, Never>] = []
    private var locationMonitoringRequests: [Bool] = []

    func observe() -> AsyncStream<VehicleSessionSnapshot> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<VehicleSessionSnapshot>.makeStream(bufferingPolicy: .unbounded)
        continuations[id] = continuation
        continuation.onTermination = { _ in
            Task { await self.removeObserver(id) }
        }
        let waiters = subscriberWaiters
        subscriberWaiters.removeAll()
        waiters.forEach { $0.resume() }
        return stream
    }

    func start() async {}
    func stop() async {}
    func refreshBikeStatus() async {}
    func zeroBikeAttitude() async {}
    func setBatteryHealthMonitoringRequired(_: Bool, consumerID _: UUID) async {}

    func setLocationMonitoringRequired(_ required: Bool, consumerID _: UUID) async {
        locationMonitoringRequests.append(required)
    }

    func send(_ snapshot: VehicleSessionSnapshot) async {
        if continuations.isEmpty {
            await withCheckedContinuation { continuation in
                subscriberWaiters.append(continuation)
            }
        }
        continuations.values.forEach { $0.yield(snapshot) }
    }

    func requestedLocationMonitoring() -> [Bool] {
        locationMonitoringRequests
    }

    func activeObserverCount() -> Int {
        continuations.count
    }

    private func removeObserver(_ id: UUID) {
        continuations[id] = nil
    }
}
