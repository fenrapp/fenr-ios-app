@testable import BikeEmulator
import Foundation

actor ControllableBikeEmulatorRuntime {
    nonisolated let telemetryInterval: Duration
    nonisolated let imuInterval: Duration

    private var currentDate: Date
    private var sleepWaiters: [SleepWaiter] = []
    private var nowWaiters: [CheckedContinuation<Void, Never>] = []
    private var isNowSuspended = false
    private var resumesCanceledSleeps = true

    init(
        date: Date = Date(timeIntervalSince1970: 1_700_000_000),
        telemetryInterval: Duration = .seconds(1),
        imuInterval: Duration = .milliseconds(100)
    ) {
        currentDate = date
        self.telemetryInterval = telemetryInterval
        self.imuInterval = imuInterval
    }

    func makeRuntime() -> BikeEmulatorRuntime {
        BikeEmulatorRuntime(
            now: { await self.now() },
            sleep: { duration in try await self.sleep(for: duration) },
            telemetryInterval: telemetryInterval,
            imuInterval: imuInterval
        )
    }

    func setDate(_ date: Date) {
        currentDate = date
    }

    func suspendNow() {
        isNowSuspended = true
    }

    func resumeNow() {
        isNowSuspended = false
        let waiters = nowWaiters
        nowWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    func nowWaiterCount() -> Int {
        nowWaiters.count
    }

    func setResumesCanceledSleeps(_ resumes: Bool) {
        resumesCanceledSleeps = resumes
    }

    func waiterCount(for interval: Duration) -> Int {
        sleepWaiters.count { $0.interval == interval }
    }

    @discardableResult
    func resumeNext(for interval: Duration, date: Date? = nil) -> Bool {
        guard let index = sleepWaiters.firstIndex(where: { $0.interval == interval }) else {
            return false
        }
        if let date {
            currentDate = date
        }
        let waiter = sleepWaiters.remove(at: index)
        waiter.continuation.resume()
        return true
    }

    func resumeAll(date: Date? = nil) {
        if let date {
            currentDate = date
        }
        let waiters = sleepWaiters
        sleepWaiters.removeAll()
        waiters.forEach { $0.continuation.resume() }
    }

    private func now() async -> Date {
        if isNowSuspended {
            await withCheckedContinuation { continuation in
                nowWaiters.append(continuation)
            }
        }
        return currentDate
    }

    private func sleep(for interval: Duration) async throws {
        let identifier = UUID()
        try Task.checkCancellation()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                sleepWaiters.append(.init(
                    identifier: identifier,
                    interval: interval,
                    continuation: continuation
                ))
            }
        } onCancel: {
            Task { await self.cancelSleep(identifier: identifier) }
        }
    }

    private func cancelSleep(identifier: UUID) {
        guard resumesCanceledSleeps,
              let index = sleepWaiters.firstIndex(where: { $0.identifier == identifier })
        else { return }
        let waiter = sleepWaiters.remove(at: index)
        waiter.continuation.resume(throwing: CancellationError())
    }
}

private struct SleepWaiter {
    let identifier: UUID
    let interval: Duration
    let continuation: CheckedContinuation<Void, any Error>
}
