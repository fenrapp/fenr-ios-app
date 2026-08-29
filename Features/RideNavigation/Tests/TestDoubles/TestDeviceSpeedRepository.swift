import EnvironmentDomain
import Foundation

actor TestDeviceSpeedRepository: DeviceSpeedRepository {
    private var continuations: [UUID: AsyncStream<DeviceSpeedSample>.Continuation] = [:]

    func observeDeviceSpeed() -> AsyncStream<DeviceSpeedSample> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<DeviceSpeedSample>.makeStream()
        continuations[id] = continuation
        continuation.onTermination = { _ in
            Task { await self.removeObserver(id) }
        }
        return stream
    }

    func locationAuthorizationStatus() async -> LocationAuthorizationStatus {
        .authorized
    }

    func requestLocationAuthorization() async {}

    func send(_ sample: DeviceSpeedSample) async {
        while continuations.isEmpty {
            await Task.yield()
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
