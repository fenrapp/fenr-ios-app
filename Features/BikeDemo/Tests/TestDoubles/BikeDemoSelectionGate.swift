import Foundation

/// Holds emulator publication after a scenario write, deliberately ignoring cancellation.
final class BikeDemoSelectionGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuations: [CheckedContinuation<Date, Never>] = []
    private var isFinished = false
    private var requests = 0
    private var cancellations = 0

    var requestCount: Int { lock.withLock { requests } }
    var cancellationCount: Int { lock.withLock { cancellations } }

    func now() async -> Date {
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                let shouldResume = lock.withLock {
                    requests += 1
                    guard !isFinished else { return true }
                    continuations.append(continuation)
                    return false
                }
                if shouldResume { continuation.resume(returning: Self.date) }
            }
        } onCancel: {
            self.lock.withLock { self.cancellations += 1 }
        }
    }

    func resumeNext() {
        let continuation = lock.withLock {
            continuations.isEmpty ? nil : continuations.removeFirst()
        }
        continuation?.resume(returning: Self.date)
    }

    func finish() {
        let pending = lock.withLock {
            isFinished = true
            let pending = continuations
            continuations = []
            return pending
        }
        pending.forEach { $0.resume(returning: Self.date) }
    }

    private static let date = Date(timeIntervalSince1970: 1_700_000_000)
}
