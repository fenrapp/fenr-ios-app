@MainActor
public final class BikeBLEOperationTimeoutScheduler: BikeBLETimeoutScheduling {
    private let duration: Duration
    private var task: Task<Void, Never>?

    public init(duration: Duration) {
        self.duration = duration
    }

    var hasPendingOperation: Bool {
        task != nil
    }

    deinit {
        task?.cancel()
    }

    public func schedule(operation: @escaping @MainActor @Sendable () async -> Void) {
        task?.cancel()
        task = Task { @MainActor [weak self, duration] in
            do {
                try await Task.sleep(for: duration)
            } catch {
                return
            }
            guard let self, !Task.isCancelled else { return }
            self.task = nil
            await operation()
        }
    }

    public func cancel() {
        task?.cancel()
        task = nil
    }
}
