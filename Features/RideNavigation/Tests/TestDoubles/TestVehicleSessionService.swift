import Foundation
import VehicleSession

struct VehicleSessionLifecycleCallCounts: Equatable {
    let starts: Int
    let stops: Int
}

actor TestVehicleSessionService: VehicleSessionService {
    private var continuations: [UUID: AsyncStream<VehicleSessionSnapshot>.Continuation] = [:]
    private var subscriberWaiters: [CheckedContinuation<Void, Never>] = []
    private var locationMonitoringRequests: [Bool] = []
    private var startCallCount = 0
    private var stopCallCount = 0

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

    func start() async { startCallCount += 1 }
    func stop() async { stopCallCount += 1 }
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

    func lifecycleCallCounts() -> VehicleSessionLifecycleCallCounts {
        VehicleSessionLifecycleCallCounts(starts: startCallCount, stops: stopCallCount)
    }

    private func removeObserver(_ id: UUID) {
        continuations[id] = nil
    }
}
