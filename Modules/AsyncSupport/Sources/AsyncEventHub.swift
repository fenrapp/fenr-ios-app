import Foundation

public actor AsyncEventHub<Value: Sendable> {
    private var continuations: [UUID: AsyncStream<Value>.Continuation] = [:]
    private var latestValue: Value?
    private let bufferingPolicy: AsyncStream<Value>.Continuation.BufferingPolicy
    private let replaysLatestValue: Bool

    public init(
        bufferingPolicy: AsyncStream<Value>.Continuation.BufferingPolicy = .unbounded,
        replaysLatestValue: Bool = false
    ) {
        self.bufferingPolicy = bufferingPolicy
        self.replaysLatestValue = replaysLatestValue
    }

    public func stream(replay: Value? = nil) -> AsyncStream<Value> {
        let identifier = UUID()
        let (stream, continuation) = AsyncStream<Value>.makeStream(bufferingPolicy: bufferingPolicy)
        continuations[identifier] = continuation

        if let replay {
            continuation.yield(replay)
        } else if replaysLatestValue, let latestValue {
            continuation.yield(latestValue)
        }

        continuation.onTermination = { _ in
            Task { await self.remove(identifier: identifier) }
        }
        return stream
    }

    public func send(_ value: Value) {
        if replaysLatestValue {
            latestValue = value
        }
        continuations.values.forEach { $0.yield(value) }
    }

    private func remove(identifier: UUID) {
        continuations[identifier] = nil
    }
}
