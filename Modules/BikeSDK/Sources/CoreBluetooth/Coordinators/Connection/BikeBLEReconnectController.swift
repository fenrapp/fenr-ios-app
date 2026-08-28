import Foundation

@MainActor
final class BikeBLEReconnectController {
    typealias ScheduledHandler = @MainActor (Int, Int) async -> Void
    typealias ReconnectOperation = @MainActor @Sendable () async -> Void

    private let delay: any BikeBLEReconnectDelaying
    private let policy: BikeBLEReconnectPolicy
    private let connectionStabilityPeriod: Duration
    private var attempt = 0
    private var task: Task<Void, Never>?
    private var stabilityTask: Task<Void, Never>?
    private var stabilityGeneration = 0

    var hasPendingReconnect: Bool {
        task != nil
    }

    init(
        delay: any BikeBLEReconnectDelaying,
        policy: BikeBLEReconnectPolicy,
        connectionStabilityPeriod: Duration
    ) {
        self.delay = delay
        self.policy = policy
        self.connectionStabilityPeriod = connectionStabilityPeriod
    }

    deinit {
        task?.cancel()
        stabilityTask?.cancel()
    }

    func schedule(
        onScheduled: ScheduledHandler,
        operation: @escaping ReconnectOperation
    ) async -> Bool {
        cancelPendingStability()
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
        cancelPendingStability()
        attempt = 0
    }

    func markConnectionReady() {
        cancelPendingStability()
        let generation = stabilityGeneration
        let stabilityPeriod = connectionStabilityPeriod
        stabilityTask = Task { @MainActor [weak self, delay] in
            do {
                try await delay.wait(for: stabilityPeriod)
            } catch {
                return
            }
            guard let self, self.stabilityGeneration == generation else { return }
            self.stabilityTask = nil
            self.attempt = 0
        }
    }

    private func cancelPendingStability() {
        stabilityGeneration += 1
        stabilityTask?.cancel()
        stabilityTask = nil
    }
}
