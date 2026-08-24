import Foundation

@MainActor
final class BikeBLEReconnectController {
    typealias ScheduledHandler = @MainActor (Int, Int) async -> Void
    typealias ReconnectOperation = @MainActor @Sendable () async -> Void

    private let delay: any BikeBLEReconnectDelaying
    private let policy: BikeBLEReconnectPolicy
    private var attempt = 0
    private var task: Task<Void, Never>?

    var hasPendingReconnect: Bool {
        task != nil
    }

    init(delay: any BikeBLEReconnectDelaying, policy: BikeBLEReconnectPolicy) {
        self.delay = delay
        self.policy = policy
    }

    deinit {
        task?.cancel()
    }

    func schedule(
        onScheduled: ScheduledHandler,
        operation: @escaping ReconnectOperation
    ) async -> Bool {
        let nextAttempt = attempt + 1
        guard let duration = policy.delay(forAttempt: nextAttempt) else {
            cancelPending()
            return false
        }
        attempt = nextAttempt
        await onScheduled(nextAttempt, policy.delays.count)

        task?.cancel()
        task = Task { @MainActor [weak self, delay] in
            do {
                try await delay.wait(for: duration)
            } catch {
                guard let self, self.attempt == nextAttempt else { return }
                self.task = nil
                return
            }
            guard let self, self.attempt == nextAttempt else { return }
            self.task = nil
            await operation()
        }
        return true
    }

    func cancelPending() {
        task?.cancel()
        task = nil
    }

    func reset() {
        cancelPending()
        attempt = 0
    }
}
