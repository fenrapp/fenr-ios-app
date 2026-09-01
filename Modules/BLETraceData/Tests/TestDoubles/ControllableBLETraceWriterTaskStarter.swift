import BLETraceData
import Foundation

final class ControllableBLETraceWriterTaskStarter: BLETraceWriterTaskStarter, @unchecked Sendable {
    private let gate = WriterTaskStartGate()

    func start(
        operation: @escaping @Sendable () async -> Void
    ) -> Task<Void, Never> {
        Task {
            await gate.wait()
            await operation()
        }
    }

    func waitUntilStarted(count: Int = 1) async {
        await gate.waitUntilStarted(count: count)
    }

    func resumeAll() async {
        await gate.resumeAll()
    }
}

private actor WriterTaskStartGate {
    private var isOpen = false
    private var startedCount = 0
    private var startWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private var blockedTasks: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        startedCount += 1
        resumeSatisfiedStartWaiters()
        guard !isOpen else { return }
        await withCheckedContinuation { continuation in
            blockedTasks.append(continuation)
        }
    }

    func waitUntilStarted(count: Int) async {
        guard startedCount < count else { return }
        await withCheckedContinuation { continuation in
            startWaiters.append((count, continuation))
        }
    }

    func resumeAll() {
        isOpen = true
        let tasks = blockedTasks
        blockedTasks.removeAll()
        tasks.forEach { $0.resume() }
        resumeSatisfiedStartWaiters()
    }

    private func resumeSatisfiedStartWaiters() {
        var pending: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
        for waiter in startWaiters {
            if startedCount >= waiter.count {
                waiter.continuation.resume()
            } else {
                pending.append(waiter)
            }
        }
        startWaiters = pending
    }
}
