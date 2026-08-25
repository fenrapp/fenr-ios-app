@MainActor
public final class ChargeControlTaskScheduler {
    private let debounceDelay: Duration
    private let confirmationDelay: Duration
    private var powerDebounceTask: Task<Void, Never>?
    private var powerConfirmationTask: Task<Void, Never>?
    private var targetDebounceTask: Task<Void, Never>?
    private var targetConfirmationTask: Task<Void, Never>?

    public init(
        debounceDelay: Duration = .seconds(1),
        confirmationDelay: Duration = .seconds(5)
    ) {
        self.debounceDelay = debounceDelay
        self.confirmationDelay = confirmationDelay
    }

    deinit {
        powerDebounceTask?.cancel()
        powerConfirmationTask?.cancel()
        targetDebounceTask?.cancel()
        targetConfirmationTask?.cancel()
    }

    func cancelAll() {
        cancelPowerDebounce()
        cancelPowerConfirmation()
        cancelTargetDebounce()
        cancelTargetConfirmation()
    }

    func cancelPowerDebounce() {
        powerDebounceTask?.cancel()
        powerDebounceTask = nil
    }

    func cancelPowerConfirmation() {
        powerConfirmationTask?.cancel()
        powerConfirmationTask = nil
    }

    func cancelTargetDebounce() {
        targetDebounceTask?.cancel()
        targetDebounceTask = nil
    }

    func cancelTargetConfirmation() {
        targetConfirmationTask?.cancel()
        targetConfirmationTask = nil
    }

    func schedulePowerDebounce(operation: @escaping @MainActor () async -> Void) {
        cancelPowerDebounce()
        powerDebounceTask = delayedTask(delay: debounceDelay, operation: operation)
    }

    func scheduleTargetDebounce(operation: @escaping @MainActor () async -> Void) {
        cancelTargetDebounce()
        targetDebounceTask = delayedTask(delay: debounceDelay, operation: operation)
    }

    func schedulePowerConfirmation(operation: @escaping @MainActor () async -> Void) {
        cancelPowerConfirmation()
        powerConfirmationTask = delayedTask(delay: confirmationDelay, operation: operation)
    }

    func scheduleTargetConfirmation(operation: @escaping @MainActor () async -> Void) {
        cancelTargetConfirmation()
        targetConfirmationTask = delayedTask(delay: confirmationDelay, operation: operation)
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
