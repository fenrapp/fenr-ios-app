import Foundation

public actor AsyncEventHub<Value: Sendable> {
    private var continuations: [UUID: AsyncStream<Value>.Continuation] = [:]
    private var latestValue: Value?
    private var isFinished = false
    private let bufferingPolicy: AsyncStream<Value>.Continuation.BufferingPolicy
    private let replaysLatestValue: Bool

    public init(
        bufferingPolicy: AsyncStream<Value>.Continuation.BufferingPolicy,
        replaysLatestValue: Bool = false
    ) {
        self.bufferingPolicy = bufferingPolicy
        self.replaysLatestValue = replaysLatestValue
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
        } else if replaysLatestValue, let latestValue {
            continuation.yield(latestValue)
        }

        continuation.onTermination = { [weak self] _ in
            Task { await self?.remove(identifier: identifier) }
        }
        return stream
    }

    public func send(_ value: Value) {
        guard !isFinished else { return }

        if replaysLatestValue {
            latestValue = value
        }

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

    public func finish() {
        guard !isFinished else { return }

        isFinished = true
        latestValue = nil
        let activeContinuations = Array(continuations.values)
        continuations.removeAll()
        activeContinuations.forEach { $0.finish() }
    }

    private func remove(identifier: UUID) {
        continuations[identifier] = nil
    }

    deinit {
        continuations.values.forEach { $0.finish() }
    }
}
