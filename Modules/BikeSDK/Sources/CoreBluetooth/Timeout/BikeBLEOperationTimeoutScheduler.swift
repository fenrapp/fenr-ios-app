@MainActor
public final class BikeBLEOperationTimeoutScheduler: BikeBLETimeoutScheduling {
    private let duration: Duration
    private var task: Task<Void, Never>?

    public init(duration: Duration) {
        self.duration = duration
    }

    deinit {
        task?.cancel()
    }

    public func schedule(operation: @escaping @MainActor @Sendable () async -> Void) {
        task?.cancel()
        task = Task { @MainActor [duration] in
            do {
                try await Task.sleep(for: duration)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await operation()
        }
    }

    public func cancel() {
        task?.cancel()
        task = nil
    }
}
