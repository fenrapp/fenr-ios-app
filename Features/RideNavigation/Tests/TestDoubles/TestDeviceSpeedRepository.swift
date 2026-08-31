import EnvironmentDomain
import Foundation

actor TestDeviceSpeedRepository: DeviceSpeedRepository {
    private var continuations: [UUID: AsyncStream<DeviceSpeedSample>.Continuation] = [:]
    private var subscriberWaiters: [CheckedContinuation<Void, Never>] = []

    func observeDeviceSpeed() -> AsyncStream<DeviceSpeedSample> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<DeviceSpeedSample>.makeStream(bufferingPolicy: .unbounded)
        continuations[id] = continuation
        continuation.onTermination = { _ in
            Task { await self.removeObserver(id) }
        }
        let waiters = subscriberWaiters
        subscriberWaiters.removeAll()
        waiters.forEach { $0.resume() }
        return stream
    }

    func locationAuthorizationStatus() async -> LocationAuthorizationStatus {
        .authorized
    }

    func requestLocationAuthorization() async {}

    func send(_ sample: DeviceSpeedSample) async {
        if continuations.isEmpty {
            await withCheckedContinuation { continuation in
                subscriberWaiters.append(continuation)
            }
        }
        continuations.values.forEach { $0.yield(sample) }
    }

    func activeObserverCount() -> Int {
        continuations.count
    }

    private func removeObserver(_ id: UUID) {
        continuations[id] = nil
    }
}
