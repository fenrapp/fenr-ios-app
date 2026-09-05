import Foundation

@MainActor
public final class BikeBLESecurityWatchdog {
    private let sessionStore: BLESessionStore
    private let eventEmitter: BikeBLEEventEmitter
    private let timeoutScheduler: any BikeBLETimeoutScheduling
    private let timeoutRecoveryHandler: @MainActor @Sendable () async -> Void

    public init(
        sessionStore: BLESessionStore,
        eventEmitter: BikeBLEEventEmitter,
        timeoutScheduler: any BikeBLETimeoutScheduling,
        timeoutRecoveryHandler: @escaping @MainActor @Sendable () async -> Void
    ) {
        self.sessionStore = sessionStore
        self.eventEmitter = eventEmitter
        self.timeoutScheduler = timeoutScheduler
        self.timeoutRecoveryHandler = timeoutRecoveryHandler
    }

    public func watch(expectedState: BLEAuthenticationState, operation: String) {
        timeoutScheduler.schedule { [weak self] in
            guard let self else { return }
            guard self.sessionStore.discoveredCharacteristics[
                BikeSDKConstants.securityCharacteristicUUID
            ] != nil else { return }
            guard self.sessionStore.authenticationState == expectedState else { return }
            await self.fail("Security operation timed out: \(operation)")
            await self.timeoutRecoveryHandler()
        }
    }

    public func cancel() {
        timeoutScheduler.cancel()
    }

    public func handle(error: Error, characteristicUUID: String) async {
        let detail = "\(BikeSDKText.securityChallenge) \(characteristicUUID): \(error.localizedDescription)"
        await eventEmitter.sendDiagnostic(.debug(.init(title: BikeSDKText.pairingTitle, detail: detail)))
        await fail(error.requiresPairingOrEncryption ? BikeSDKText.securityChallengeGuidance : detail)
    }

    public func fail(_ message: String) async {
        cancel()
        sessionStore.setAuthenticationState(.failed)
        await eventEmitter.send(.error(.operationFailed(message)))
    }
}
