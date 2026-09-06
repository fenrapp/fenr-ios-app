import EnvironmentDomain
import Foundation

final class ControllableLocationRepository: DeviceSpeedRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var pendingRead: CheckedContinuation<LocationAuthorizationStatus, Never>?
    private var readWasCancelled = false

    var hasPendingRead: Bool { lock.withLock { pendingRead != nil } }
    var wasCancelled: Bool { lock.withLock { readWasCancelled } }

    func observeDeviceSpeed() -> AsyncStream<DeviceSpeedSample> {
        .init { $0.finish() }
    }

    func locationAuthorizationStatus() async -> LocationAuthorizationStatus {
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                lock.withLock { pendingRead = continuation }
            }
        } onCancel: {
            self.lock.withLock { self.readWasCancelled = true }
        }
    }

    func requestLocationAuthorization() {}

    func completeRead(with status: LocationAuthorizationStatus) {
        let continuation = lock.withLock {
            let continuation = pendingRead
            pendingRead = nil
            return continuation
        }
        continuation?.resume(returning: status)
    }
}
