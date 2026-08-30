import Foundation

struct ManualTestInstant: InstantProtocol {
    let offset: Duration

    func advanced(by duration: Duration) -> ManualTestInstant {
        .init(offset: offset + duration)
    }

    func duration(to other: ManualTestInstant) -> Duration {
        other.offset - offset
    }

    static func < (lhs: ManualTestInstant, rhs: ManualTestInstant) -> Bool {
        lhs.offset < rhs.offset
    }
}

struct ManualTestClock: Clock {
    typealias Duration = Swift.Duration
    typealias Instant = ManualTestInstant

    private let state = ManualTestClockState()

    var now: ManualTestInstant {
        state.now
    }

    var minimumResolution: Duration {
        .nanoseconds(1)
    }

    func sleep(until _: ManualTestInstant, tolerance _: Duration?) async throws {
        throw ManualTestClockError.unsupportedDirectSleep
    }

    func advance(by duration: Duration) {
        state.advance(by: duration)
    }

    func recordSleepAndAdvance(to deadline: ManualTestInstant) {
        state.recordSleepAndAdvance(to: deadline)
    }

    func recordedSleepDeadlines() -> [ManualTestInstant] {
        state.recordedSleepDeadlines
    }
}

private final class ManualTestClockState: @unchecked Sendable {
    private let lock = NSLock()
    private var nowStorage = ManualTestInstant(offset: .zero)
    private var sleepDeadlinesStorage: [ManualTestInstant] = []

    var now: ManualTestInstant {
        lock.withLock { nowStorage }
    }

    var recordedSleepDeadlines: [ManualTestInstant] {
        lock.withLock { sleepDeadlinesStorage }
    }

    func advance(by duration: Duration) {
        lock.withLock {
            nowStorage = nowStorage.advanced(by: duration)
        }
    }

    func recordSleepAndAdvance(to deadline: ManualTestInstant) {
        lock.withLock {
            sleepDeadlinesStorage.append(deadline)
            nowStorage = max(nowStorage, deadline)
        }
    }
}

private enum ManualTestClockError: Error {
    case unsupportedDirectSleep
}
