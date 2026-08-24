import CoreBluetooth
import Foundation
import StarkProtocol

@MainActor
public final class BikeBLESecurityCoordinator {
    private let sessionStore: BLESessionStore
    private let eventEmitter: BikeBLEEventEmitter
    private let watchdog: BikeBLESecurityWatchdog
    private let handshake: BikeBLESecurityHandshake
    private let pairingRetryController: BikeBLEPairingRetryController?

    init(
        sessionStore: BLESessionStore,
        eventEmitter: BikeBLEEventEmitter,
        watchdog: BikeBLESecurityWatchdog,
        handshake: BikeBLESecurityHandshake,
        pairingRetryController: BikeBLEPairingRetryController? = nil
    ) {
        self.sessionStore = sessionStore
        self.eventEmitter = eventEmitter
        self.watchdog = watchdog
        self.handshake = handshake
        self.pairingRetryController = pairingRetryController
    }

    public func handles(_ characteristic: CBCharacteristic) -> Bool {
        characteristic.uuid == BikeSDKConstants.securityCharacteristicUUID
    }

    public func cancelPendingRetry() {
        pairingRetryController?.reset()
    }

    public func discovered(characteristic: CBCharacteristic, peripheral: CBPeripheral) async {
        sessionStore.setCharacteristic(characteristic)
        await eventEmitter.send(.debug(.init(
            title: BikeSDKText.characteristicTitle,
            detail: "\(characteristic.uuid.uuidString) \(characteristic.properties.protocolDescription)"
        )))
        guard characteristic.properties.contains(BikeSDKConstants.securityRequiredProperties) else {
            await watchdog.fail(BikeSDKText.securityPropertiesInvalid)
            return
        }
        watchdog.watch(expectedState: .idle, operation: "descriptor discovery")
        peripheral.discoverDescriptors(for: characteristic)
    }

    public func didDiscoverDescriptors(
        peripheral: CBPeripheral,
        characteristic: CBCharacteristic,
        error: Error?
    ) async {
        watchdog.cancel()
        let characteristicUUID = characteristic.uuid.uuidString
        if let error {
            await watchdog.fail(
                "Security descriptor discovery failed \(characteristicUUID): \(error.localizedDescription)"
            )
            return
        }

        let descriptorUUIDs = characteristic.descriptors?.map(\.uuid.uuidString).joined(separator: ",")
        await eventEmitter.send(.debug(.init(
            title: BikeSDKText.descriptorTitle,
            detail: "\(characteristicUUID) \(descriptorUUIDs ?? BikeSDKText.noDescriptors)"
        )))

        guard characteristic.hasClientConfigurationDescriptor else {
            await watchdog.fail(BikeSDKText.securityCCCDMissing)
            return
        }

        await handshake.enableNotifications(peripheral: peripheral, characteristic: characteristic)
    }

    public func didUpdateNotificationState(
        peripheral: CBPeripheral,
        characteristic: CBCharacteristic,
        error: Error?
    ) async {
        if sessionStore.authenticationState == .authenticated {
            let detail = error?.localizedDescription ?? BikeSDKText.securityNotificationsDisabled
            await eventEmitter.send(.debug(.init(
                title: BikeSDKText.securityTitle,
                detail: detail
            )))
            return
        }

        watchdog.cancel()
        if let error {
            await watchdog.fail("Security subscription failed: \(error.localizedDescription)")
            return
        }

        guard characteristic.isNotifying else {
            await watchdog.fail(BikeSDKText.securityNotificationsDisabled)
            return
        }

        sessionStore.setSubscribed(characteristic.uuid)
        await eventEmitter.send(.debug(.init(
            title: BikeSDKText.securityTitle,
            detail: BikeSDKText.securityNotificationsEnabled
        )))
        await handshake.readNonce(peripheral: peripheral, characteristic: characteristic)
    }

    public func didUpdateValue(
        peripheral: CBPeripheral,
        characteristic: CBCharacteristic,
        error: Error?
    ) async {
        if let error {
            await handleSecurityError(error, characteristic: characteristic)
            return
        }

        guard let data = characteristic.value else {
            await watchdog.fail("Security update contained no data")
            return
        }

        switch sessionStore.authenticationState {
        case .readingNonce:
            await handshake.handleNonce(data, peripheral: peripheral, characteristic: characteristic)
        case .writingResponse, .waitingForResult:
            cancelPendingRetry()
            await handshake.handleAuthenticationResult(data, peripheral: peripheral, characteristic: characteristic)
        case .idle, .enablingNotifications, .authenticated, .failed:
            await eventEmitter.send(.debug(.init(
                title: BikeSDKText.securityTitle,
                detail: BikeSDKText.securityUpdateIgnored
            )))
        }
    }

    public func didWriteValue(characteristic: CBCharacteristic, error: Error?) async {
        guard handles(characteristic) else { return }
        guard sessionStore.authenticationState == .writingResponse else { return }
        if let error {
            await watchdog.fail("Security response write failed: \(error.localizedDescription)")
            return
        }

        sessionStore.setAuthenticationState(.waitingForResult)
        watchdog.watch(expectedState: .waitingForResult, operation: "authentication result")
        await eventEmitter.send(.debug(.init(
            title: BikeSDKText.securityTitle,
            detail: BikeSDKText.securityPayloadWritten
        )))
    }

    public func retry() async throws {
        guard let peripheral = sessionStore.peripheral else {
            try await eventEmitter.fail(.operationFailed(BikeSDKText.noActivePeripheral))
            return
        }
        guard let characteristic = sessionStore.discoveredCharacteristics[
            BikeSDKConstants.securityCharacteristicUUID
        ] else {
            try await eventEmitter.fail(.operationFailed(BikeSDKText.securityCharacteristicMissing))
            return
        }

        switch sessionStore.authenticationState {
        case .authenticated:
            cancelPendingRetry()
            await eventEmitter.send(.debug(.init(
                title: BikeSDKText.securityTitle,
                detail: BikeSDKText.securityAlreadyAuthenticated
            )))
            return
        case .enablingNotifications, .readingNonce, .writingResponse, .waitingForResult:
            await eventEmitter.send(.debug(.init(
                title: BikeSDKText.securityTitle,
                detail: BikeSDKText.securityAlreadyRunning
            )))
            return
        case .idle, .failed:
            pairingRetryController?.cancelScheduledRetry()
        }

        await eventEmitter.send(.debug(.init(
            title: BikeSDKText.pairingTitle,
            detail: "\(BikeSDKText.manualSecurityRetry) \(characteristic.uuid.uuidString)"
        )))
        if characteristic.isNotifying {
            await handshake.readNonce(peripheral: peripheral, characteristic: characteristic)
        } else {
            await handshake.enableNotifications(peripheral: peripheral, characteristic: characteristic)
        }
    }

    private func handleSecurityError(_ error: Error, characteristic: CBCharacteristic) async {
        let shouldRetryPairing = pairingRetryController != nil && error.requiresPairingOrEncryption
        await watchdog.handle(error: error, characteristicUUID: characteristic.uuid.uuidString)
        guard shouldRetryPairing else { return }
        pairingRetryController?.schedule(characteristicUUID: characteristic.uuid) { [weak self] attempt, uuid in
            await self?.retryAfterPairingDelay(attempt: attempt, characteristicUUID: uuid)
        }
    }

    private func retryAfterPairingDelay(attempt: Int, characteristicUUID: CBUUID) async {
        guard sessionStore.authenticationState == .failed else { return }
        guard let characteristic = sessionStore.discoveredCharacteristics[characteristicUUID],
              let peripheral = sessionStore.peripheral
        else { return }
        pairingRetryController?.cancelScheduledRetry()
        await eventEmitter.send(.debug(.init(
            title: BikeSDKText.pairingTitle,
            detail: "Automatic security retry \(attempt) running"
        )))
        if characteristic.isNotifying {
            await handshake.readNonce(peripheral: peripheral, characteristic: characteristic)
        } else {
            await handshake.enableNotifications(peripheral: peripheral, characteristic: characteristic)
        }
    }
}
