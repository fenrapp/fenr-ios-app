import Foundation

@MainActor
public final class BikeBLESecurityWatchdog {
    private let sessionStore: BLESessionStore
    private let eventEmitter: BikeBLEEventEmitter
    private let timeoutScheduler: any BikeBLETimeoutScheduling

    public init(
        sessionStore: BLESessionStore,
        eventEmitter: BikeBLEEventEmitter,
        timeoutScheduler: any BikeBLETimeoutScheduling
    ) {
        self.sessionStore = sessionStore
        self.eventEmitter = eventEmitter
        self.timeoutScheduler = timeoutScheduler
    }

    public func watch(expectedState: BLEAuthenticationState, operation: String) {
        timeoutScheduler.schedule { [weak self] in
            guard let self else { return }
            guard self.sessionStore.discoveredCharacteristics[
                BikeSDKConstants.securityCharacteristicUUID
            ] != nil else { return }
            guard self.sessionStore.authenticationState == expectedState else { return }
            await self.fail("Security operation timed out: \(operation)")
        }
    }

    public func cancel() {
        timeoutScheduler.cancel()
    }

    public func handle(error: Error, characteristicUUID: String) async {
        let detail = "\(BikeSDKText.securityChallenge) \(characteristicUUID): \(error.localizedDescription)"
        await eventEmitter.send(.debug(.init(title: BikeSDKText.pairingTitle, detail: detail)))
        await fail(error.requiresPairingOrEncryption ? BikeSDKText.securityChallengeGuidance : detail)
    }

    public func fail(_ message: String) async {
        cancel()
        sessionStore.setAuthenticationState(.failed)
        await eventEmitter.send(.error(.operationFailed(message)))
    }
}
