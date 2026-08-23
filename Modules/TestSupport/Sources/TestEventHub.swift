import Foundation

public actor TestEventHub<Value: Sendable> {
    private var continuations: [UUID: AsyncStream<Value>.Continuation] = [:]
    private var subscriberWaiters: [CheckedContinuation<Void, Never>] = []

    public init() {}

    public func stream(replay: Value? = nil) -> AsyncStream<Value> {
        let identifier = UUID()
        let (stream, continuation) = AsyncStream<Value>.makeStream()
        continuations[identifier] = continuation
        resumeSubscriberWaiters()

        if let replay {
            continuation.yield(replay)
        }

        continuation.onTermination = { _ in
            Task { await self.remove(identifier: identifier) }
        }
        return stream
    }

    public func send(_ value: Value) {
        continuations.values.forEach { $0.yield(value) }
    }

    public func waitForSubscriber() async {
        guard continuations.isEmpty else { return }

        await withCheckedContinuation { continuation in
            subscriberWaiters.append(continuation)
        }
    }

    private func remove(identifier: UUID) {
        continuations[identifier] = nil
    }

    private func resumeSubscriberWaiters() {
        let waiters = subscriberWaiters
        subscriberWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }
}
