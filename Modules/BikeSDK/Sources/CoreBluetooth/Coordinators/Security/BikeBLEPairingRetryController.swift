import CoreBluetooth

@MainActor
final class BikeBLEPairingRetryController {
    private let eventEmitter: BikeBLEEventEmitter
    private let recoveryHandler: (@MainActor @Sendable () async -> Void)?
    private var retryTask: Task<Void, Never>?
    private var retryAttempt = 0
    private var didRequestRecovery = false

    init(
        eventEmitter: BikeBLEEventEmitter,
        recoveryHandler: (@MainActor @Sendable () async -> Void)?
    ) {
        self.eventEmitter = eventEmitter
        self.recoveryHandler = recoveryHandler
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
    ) {
        retryTask?.cancel()
        guard retryAttempt < Constants.maximumAttempts else {
            emitRetryLimitAndRecover()
            return
        }
        retryAttempt += 1
        let attempt = retryAttempt
        retryTask = Task { [eventEmitter] in
            await eventEmitter.send(.debug(.init(
                title: BikeSDKText.pairingTitle,
                detail: "Automatic security retry \(attempt)/\(Constants.maximumAttempts) scheduled"
            )))
            do {
                try await Task.sleep(for: Constants.retryDelay)
            } catch {
                return
            }
            await retry(attempt, characteristicUUID)
        }
    }

    private func emitRetryLimitAndRecover() {
        Task { [eventEmitter] in
            await eventEmitter.send(.debug(.init(
                title: BikeSDKText.pairingTitle,
                detail: "Automatic security retry limit reached"
            )))
        }
        recoverIfNeeded()
    }

    func recoverIfNeeded() {
        guard !didRequestRecovery, let recoveryHandler else { return }
        didRequestRecovery = true
        Task {
            await recoveryHandler()
        }
    }

    private enum Constants {
        static let maximumAttempts = 3
        static let retryDelay: Duration = .seconds(3)
    }
}
