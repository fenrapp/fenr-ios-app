import CoreBluetooth
import Foundation
import StarkProtocol

@MainActor
public final class BikeBLESecurityCoordinator {
    private let sessionStore: BLESessionStore
    private let eventEmitter: BikeBLEEventEmitter
    private let payloadBuilder: any StarkAuthenticationPayloadBuilding
    private let configuration: BikeSecurityConfiguration
    private let notificationCoordinator: BikeBLENotificationCoordinator
    private let watchdog: BikeBLESecurityWatchdog

    public init(
        sessionStore: BLESessionStore,
        eventEmitter: BikeBLEEventEmitter,
        payloadBuilder: any StarkAuthenticationPayloadBuilding,
        configuration: BikeSecurityConfiguration,
        notificationCoordinator: BikeBLENotificationCoordinator,
        watchdog: BikeBLESecurityWatchdog
    ) {
        self.sessionStore = sessionStore
        self.eventEmitter = eventEmitter
        self.payloadBuilder = payloadBuilder
        self.configuration = configuration
        self.notificationCoordinator = notificationCoordinator
        self.watchdog = watchdog
    }

    public func handles(_ characteristic: CBCharacteristic) -> Bool {
        characteristic.uuid == BikeSDKConstants.securityCharacteristicUUID
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

        await enableNotifications(peripheral: peripheral, characteristic: characteristic)
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
        await readNonce(peripheral: peripheral, characteristic: characteristic)
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
            await handleNonce(data, peripheral: peripheral, characteristic: characteristic)
        case .writingResponse, .waitingForResult:
            await handleAuthenticationResult(data, peripheral: peripheral, characteristic: characteristic)
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
            break
        }

        await eventEmitter.send(.debug(.init(
            title: BikeSDKText.pairingTitle,
            detail: "\(BikeSDKText.manualSecurityRetry) \(characteristic.uuid.uuidString)"
        )))
        if characteristic.isNotifying {
            await readNonce(peripheral: peripheral, characteristic: characteristic)
        } else {
            await enableNotifications(peripheral: peripheral, characteristic: characteristic)
        }
    }

    private func enableNotifications(
        peripheral: CBPeripheral,
        characteristic: CBCharacteristic
    ) async {
        sessionStore.setAuthenticationState(.enablingNotifications)
        watchdog.watch(expectedState: .enablingNotifications, operation: "security subscription")
        await eventEmitter.send(.debug(.init(
            title: BikeSDKText.subscriptionTitle,
            detail: "Enabling \(characteristic.uuid.uuidString)"
        )))
        peripheral.setNotifyValue(true, for: characteristic)
    }

    private func readNonce(peripheral: CBPeripheral, characteristic: CBCharacteristic) async {
        sessionStore.setAuthenticationState(.readingNonce)
        watchdog.watch(expectedState: .readingNonce, operation: "nonce read")
        await eventEmitter.send(.connection(.authenticating(peripheralName: peripheral.name)))
        await eventEmitter.send(.debug(.init(
            title: BikeSDKText.securityTitle,
            detail: BikeSDKText.securityNonceRead
        )))
        peripheral.readValue(for: characteristic)
    }

    private func handleNonce(
        _ nonce: Data,
        peripheral: CBPeripheral,
        characteristic: CBCharacteristic
    ) async {
        guard nonce.count == StarkAuthenticationConstants.nonceLength else {
            await watchdog.fail(
                "Security nonce has \(nonce.count) bytes; expected "
                    + "\(StarkAuthenticationConstants.nonceLength)"
            )
            return
        }

        await eventEmitter.send(.debug(.init(
            title: BikeSDKText.securityTitle,
            detail: BikeSDKText.securityNonceReceived
        )))

        do {
            let payload = try payloadBuilder.buildVersionTwo(
                vin: sessionStore.targetVIN,
                pairingDate: configuration.pairingDate,
                nonce: nonce
            )
            sessionStore.setAuthenticationState(.writingResponse)
            watchdog.watch(expectedState: .writingResponse, operation: "security response write")
            await eventEmitter.send(.debug(.init(
                title: BikeSDKText.securityTitle,
                detail: "Writing V2 response: \(payload.count) bytes"
            )))
            peripheral.writeValue(payload, for: characteristic, type: .withResponse)
        } catch {
            await watchdog.fail("Security payload build failed: \(error)")
        }
    }

    private func handleAuthenticationResult(
        _ data: Data,
        peripheral: CBPeripheral,
        characteristic: CBCharacteristic
    ) async {
        guard let result = data.first else {
            await watchdog.fail("Security result was empty")
            return
        }
        guard result == StarkAuthenticationConstants.successCode else {
            await watchdog.fail("\(BikeSDKText.securityAuthenticationFailed): code \(result)")
            return
        }

        watchdog.cancel()
        sessionStore.setAuthenticationState(.authenticated)
        await eventEmitter.send(.debug(.init(
            title: BikeSDKText.securityTitle,
            detail: BikeSDKText.securityAuthenticated
        )))
        await eventEmitter.send(.connection(.authenticated(peripheralName: peripheral.name)))
        peripheral.setNotifyValue(false, for: characteristic)
        await notificationCoordinator.authenticationDidSucceed(peripheral: peripheral)
    }

    private func handleSecurityError(_ error: Error, characteristic: CBCharacteristic) async {
        await watchdog.handle(error: error, characteristicUUID: characteristic.uuid.uuidString)
    }
}
