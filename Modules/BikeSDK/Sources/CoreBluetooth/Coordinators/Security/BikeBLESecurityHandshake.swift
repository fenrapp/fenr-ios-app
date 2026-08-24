import CoreBluetooth
import Foundation
import StarkProtocol

@MainActor
final class BikeBLESecurityHandshake {
    private let sessionStore: BLESessionStore
    private let eventEmitter: BikeBLEEventEmitter
    private let payloadBuilder: any StarkAuthenticationPayloadBuilding
    private let configuration: BikeSecurityConfiguration
    private let notificationCoordinator: BikeBLENotificationCoordinator
    private let watchdog: BikeBLESecurityWatchdog

    init(
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

    func enableNotifications(
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

    func readNonce(peripheral: CBPeripheral, characteristic: CBCharacteristic) async {
        sessionStore.setAuthenticationState(.readingNonce)
        watchdog.watch(expectedState: .readingNonce, operation: "nonce read")
        await eventEmitter.send(.connection(.authenticating(peripheralName: peripheral.name)))
        await eventEmitter.send(.debug(.init(
            title: BikeSDKText.securityTitle,
            detail: BikeSDKText.securityNonceRead
        )))
        peripheral.readValue(for: characteristic)
    }

    func handleNonce(
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

    func handleAuthenticationResult(
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
}
