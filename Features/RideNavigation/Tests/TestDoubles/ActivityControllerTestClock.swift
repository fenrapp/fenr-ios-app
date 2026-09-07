import Foundation
@testable import RideNavigation

final class ActivityControllerTestClock: @unchecked Sendable {
    private struct PendingSleep {
        let duration: Duration
        let continuation: CheckedContinuation<Void, Never>
    }

    private let lock = NSLock()
    private var isFinished = false
    private var currentDate: Date
    private var sleepers: [PendingSleep] = []

    init(date: Date = Date(timeIntervalSince1970: 1_700_000_000)) {
        currentDate = date
    }

    var now: Date { lock.withLock { currentDate } }

    func advance(seconds: TimeInterval) {
        lock.withLock { currentDate = currentDate.addingTimeInterval(seconds) }
    }

    func makeTiming() -> RideNavigationTiming {
        RideNavigationTiming(
            now: { [self] in now },
            sleep: { [self] duration in
                await withCheckedContinuation { continuation in
                    let shouldFinish = lock.withLock {
                        guard !isFinished else { return true }
                        sleepers.append(.init(duration: duration, continuation: continuation))
                        return false
                    }
                    if shouldFinish { continuation.resume() }
                }
            }
        )
    }

    func pendingSleepCount(for duration: Duration) -> Int {
        lock.withLock { sleepers.count { $0.duration == duration } }
    }

    func resumeFirstSleep(for duration: Duration) {
        let continuation = lock.withLock { () -> CheckedContinuation<Void, Never>? in
            guard let index = sleepers.firstIndex(where: { $0.duration == duration }) else { return nil }
            return sleepers.remove(at: index).continuation
        }
        continuation?.resume()
    }

    func resumeAll() {
        let pending = lock.withLock {
            isFinished = true
            let pending = sleepers
            sleepers = []
            return pending
        }
        pending.forEach { $0.continuation.resume() }
    }
}
