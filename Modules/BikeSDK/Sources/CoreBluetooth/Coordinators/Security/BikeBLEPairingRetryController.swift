import CoreBluetooth

@MainActor
final class BikeBLEPairingRetryController {
    private let eventEmitter: BikeBLEEventEmitter
    private let recoveryHandler: (@MainActor @Sendable () async -> Void)?
    private let policy: BikeBLEPairingRetryPolicy
    private var retryTask: Task<Void, Never>?
    private var retryAttempt = 0
    private var didRequestRecovery = false

    init(
        eventEmitter: BikeBLEEventEmitter,
        recoveryHandler: (@MainActor @Sendable () async -> Void)?,
        policy: BikeBLEPairingRetryPolicy
    ) {
        self.eventEmitter = eventEmitter
        self.recoveryHandler = recoveryHandler
        self.policy = policy
    }

    deinit {
        retryTask?.cancel()
    }

    var hasPendingRetry: Bool {
        retryTask != nil
    }

    func reset() {
        retryTask?.cancel()
        retryTask = nil
        retryAttempt = 0
        didRequestRecovery = false
    }

    func cancelScheduledRetry() {
        retryTask?.cancel()
        retryTask = nil
    }

    func schedule(
        characteristicUUID: CBUUID,
        retry: @escaping @MainActor (Int, CBUUID) async -> Void
    ) async {
        retryTask?.cancel()
        retryTask = nil
        guard retryAttempt < policy.maximumAttempts else {
            await eventEmitter.send(.debug(.init(
                title: BikeSDKText.pairingTitle,
                detail: "Automatic security retry limit reached"
            )))
            await recoverIfNeeded()
            return
        }
        retryAttempt += 1
        let attempt = retryAttempt
        retryTask = Task { @MainActor [weak self, eventEmitter, policy] in
            await eventEmitter.send(.debug(.init(
                title: BikeSDKText.pairingTitle,
                detail: "Automatic security retry \(attempt)/\(policy.maximumAttempts) scheduled"
            )))
            do {
                try await Task.sleep(for: policy.delay)
            } catch {
                return
            }
            guard let self, self.retryAttempt == attempt else { return }
            self.retryTask = nil
            await retry(attempt, characteristicUUID)
        }
    }

    func recoverIfNeeded() async {
        guard !didRequestRecovery, let recoveryHandler else { return }
        didRequestRecovery = true
        await recoveryHandler()
    }
}

struct BikeBLEPairingRetryPolicy: Equatable, Sendable {
    let maximumAttempts: Int
    let delay: Duration

    init(maximumAttempts: Int, delay: Duration) {
        precondition(maximumAttempts >= 0)
        self.maximumAttempts = maximumAttempts
        self.delay = delay
    }
}
