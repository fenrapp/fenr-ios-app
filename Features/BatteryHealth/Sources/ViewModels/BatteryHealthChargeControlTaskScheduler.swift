@MainActor
public final class BatteryHealthChargeControlTaskScheduler {
    private var powerDebounceTask: Task<Void, Never>?
    private var powerConfirmationTask: Task<Void, Never>?
    private var targetDebounceTask: Task<Void, Never>?
    private var targetConfirmationTask: Task<Void, Never>?

    public init() {}

    func cancelAll() {
        powerDebounceTask?.cancel()
        powerConfirmationTask?.cancel()
        targetDebounceTask?.cancel()
        targetConfirmationTask?.cancel()
    }

    func cancelPowerDebounce() {
        powerDebounceTask?.cancel()
    }

    func cancelPowerConfirmation() {
        powerConfirmationTask?.cancel()
    }

    func cancelTargetDebounce() {
        targetDebounceTask?.cancel()
    }

    func cancelTargetConfirmation() {
        targetConfirmationTask?.cancel()
    }

    func schedulePowerDebounce(operation: @escaping @MainActor () async -> Void) {
        powerDebounceTask?.cancel()
        powerDebounceTask = delayedTask(delay: .seconds(1), operation: operation)
    }

    func scheduleTargetDebounce(operation: @escaping @MainActor () async -> Void) {
        targetDebounceTask?.cancel()
        targetDebounceTask = delayedTask(delay: .seconds(1), operation: operation)
    }

    func schedulePowerConfirmation(operation: @escaping @MainActor () async -> Void) {
        powerConfirmationTask?.cancel()
        powerConfirmationTask = delayedTask(delay: .seconds(5), operation: operation)
    }

    func scheduleTargetConfirmation(operation: @escaping @MainActor () async -> Void) {
        targetConfirmationTask?.cancel()
        targetConfirmationTask = delayedTask(delay: .seconds(5), operation: operation)
    }

    private func delayedTask(
        delay: Duration,
        operation: @escaping @MainActor () async -> Void
    ) -> Task<Void, Never> {
        Task {
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await operation()
        }
    }
}
