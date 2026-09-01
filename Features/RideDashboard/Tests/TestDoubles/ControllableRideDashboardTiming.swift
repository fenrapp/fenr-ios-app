import Foundation
@testable import RideDashboard

actor ControllableRideDashboardTiming {
    private struct PendingSleep {
        let id: UUID
        let duration: Duration
        let continuation: CheckedContinuation<Void, any Error>
    }

    private var sleeps: [PendingSleep] = []
    private var requestedDurations: [Duration] = []
    private var canceledBeforeRegistration: Set<UUID> = []

    nonisolated func makeTiming() -> RideDashboardTiming {
        RideDashboardTiming { [weak self] duration in
            guard let self else { throw CancellationError() }
            try await self.sleep(for: duration)
        }
    }

    func sleep(for duration: Duration) async throws {
        try Task.checkCancellation()
        let id = UUID()
        requestedDurations.append(duration)

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                registerSleep(id: id, duration: duration, continuation: continuation)
            }
        } onCancel: {
            Task { await self.cancelSleep(id: id) }
        }
    }

    func requestedSleepCount(for duration: Duration? = nil) -> Int {
        guard let duration else { return requestedDurations.count }
        return requestedDurations.count { $0 == duration }
    }

    func pendingSleepCount(for duration: Duration? = nil) -> Int {
        guard let duration else { return sleeps.count }
        return sleeps.count { $0.duration == duration }
    }

    func resumeFirstSleep(for duration: Duration) {
        guard let index = sleeps.firstIndex(where: { $0.duration == duration }) else { return }
        sleeps.remove(at: index).continuation.resume()
    }

    private func registerSleep(
        id: UUID,
        duration: Duration,
        continuation: CheckedContinuation<Void, any Error>
    ) {
        guard canceledBeforeRegistration.remove(id) == nil else {
            continuation.resume(throwing: CancellationError())
            return
        }
        sleeps.append(PendingSleep(id: id, duration: duration, continuation: continuation))
    }

    private func cancelSleep(id: UUID) {
        guard let index = sleeps.firstIndex(where: { $0.id == id }) else {
            canceledBeforeRegistration.insert(id)
            return
        }
        sleeps.remove(at: index).continuation.resume(throwing: CancellationError())
    }
}
