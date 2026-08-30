import Foundation

public actor TestEventHub<Value: Sendable> {
    private var continuations: [UUID: AsyncStream<Value>.Continuation] = [:]
    private var subscriberWaiters: [UUID: SubscriberWaiter] = [:]
    private var isFinished = false
    private let bufferingPolicy: AsyncStream<Value>.Continuation.BufferingPolicy
    private let sleep: @Sendable (Duration) async throws -> Void

    public init(bufferingPolicy: AsyncStream<Value>.Continuation.BufferingPolicy) {
        self.bufferingPolicy = bufferingPolicy
        sleep = { duration in
            try await Task.sleep(for: duration)
        }
    }

    init(
        bufferingPolicy: AsyncStream<Value>.Continuation.BufferingPolicy,
        sleep: @escaping @Sendable (Duration) async throws -> Void
    ) {
        self.bufferingPolicy = bufferingPolicy
        self.sleep = sleep
    }

    public func stream(replay: Value? = nil) -> AsyncStream<Value> {
        let (stream, continuation) = AsyncStream<Value>.makeStream(bufferingPolicy: bufferingPolicy)

        guard !isFinished else {
            continuation.finish()
            return stream
        }

        let identifier = UUID()
        continuations[identifier] = continuation

        if let replay {
            continuation.yield(replay)
        }

        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeSubscriber(identifier: identifier) }
        }
        resolveAllWaiters(subscriberWasFound: true)
        return stream
    }

    public func send(_ value: Value) {
        guard !isFinished else { return }

        var terminatedIdentifiers: [UUID] = []
        for (identifier, continuation) in continuations {
            switch continuation.yield(value) {
            case .enqueued, .dropped:
                break
            case .terminated:
                terminatedIdentifiers.append(identifier)
            @unknown default:
                break
            }
        }
        terminatedIdentifiers.forEach { continuations[$0] = nil }
    }

    public func waitForSubscriber(timeout: Duration = .seconds(1)) async -> Bool {
        guard !Task.isCancelled, !isFinished else { return false }
        guard continuations.isEmpty else { return true }
        guard timeout > .zero else { return false }

        let identifier = UUID()
        let cancellation = SubscriberWaiterCancellation()
        let sleep = self.sleep

        return await withTaskCancellationHandler {
            guard !Task.isCancelled else { return false }

            return await withCheckedContinuation { continuation in
                guard !Task.isCancelled else {
                    cancellation.cancel()
                    continuation.resume(returning: false)
                    return
                }

                let timeoutTask = Task { [weak self] in
                    do {
                        try await sleep(timeout)
                    } catch {
                        guard !Task.isCancelled else { return }
                    }

                    guard !Task.isCancelled else { return }
                    await self?.resolveWaiter(identifier: identifier, subscriberWasFound: false)
                }
                subscriberWaiters[identifier] = SubscriberWaiter(
                    continuation: continuation,
                    timeoutTask: timeoutTask,
                    cancellation: cancellation
                )
            }
        } onCancel: {
            cancellation.cancel()
            Task { [weak self] in
                await self?.resolveWaiter(identifier: identifier, subscriberWasFound: false)
            }
        }
    }

    public func finish() {
        guard !isFinished else { return }

        isFinished = true
        let activeContinuations = Array(continuations.values)
        continuations.removeAll()
        activeContinuations.forEach { $0.finish() }
        resolveAllWaiters(subscriberWasFound: false)
    }

    private func removeSubscriber(identifier: UUID) {
        continuations[identifier] = nil
    }

    private func resolveWaiter(identifier: UUID, subscriberWasFound: Bool) {
        guard let waiter = subscriberWaiters.removeValue(forKey: identifier) else { return }

        waiter.timeoutTask.cancel()
        waiter.continuation.resume(
            returning: subscriberWasFound && !waiter.cancellation.isCancelled
        )
    }

    private func resolveAllWaiters(subscriberWasFound: Bool) {
        let waiters = Array(subscriberWaiters.values)
        subscriberWaiters.removeAll()
        waiters.forEach { waiter in
            waiter.timeoutTask.cancel()
            waiter.continuation.resume(
                returning: subscriberWasFound && !waiter.cancellation.isCancelled
            )
        }
    }

    deinit {
        continuations.values.forEach { $0.finish() }
        subscriberWaiters.values.forEach { waiter in
            waiter.timeoutTask.cancel()
            waiter.continuation.resume(returning: false)
        }
    }

    private struct SubscriberWaiter {
        let continuation: CheckedContinuation<Bool, Never>
        let timeoutTask: Task<Void, Never>
        let cancellation: SubscriberWaiterCancellation
    }
}

private final class SubscriberWaiterCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var isCancelledStorage = false

    var isCancelled: Bool {
        lock.withLock { isCancelledStorage }
    }

    func cancel() {
        lock.withLock {
            isCancelledStorage = true
        }
    }
}
