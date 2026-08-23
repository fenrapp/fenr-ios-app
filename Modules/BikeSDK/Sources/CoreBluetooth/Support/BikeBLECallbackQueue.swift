@MainActor
public final class BikeBLECallbackQueue {
    public typealias Operation = @MainActor @Sendable () async -> Void

    private var continuation: AsyncStream<Operation>.Continuation?
    private var worker: Task<Void, Never>?

    public init() {}

    deinit {
        continuation?.finish()
        worker?.cancel()
    }

    public func start() {
        guard worker == nil else { return }
        let (stream, continuation) = AsyncStream<Operation>.makeStream()
        self.continuation = continuation
        worker = Task { @MainActor in
            for await operation in stream {
                guard !Task.isCancelled else { return }
                await operation()
            }
        }
    }

    public func enqueue(_ operation: @escaping Operation) {
        continuation?.yield(operation)
    }

    public func cancelPending() {
        continuation?.finish()
        continuation = nil
        worker?.cancel()
        worker = nil
    }
}
