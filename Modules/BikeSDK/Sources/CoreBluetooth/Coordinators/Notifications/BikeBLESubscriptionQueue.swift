import CoreBluetooth

@MainActor
final class BikeBLESubscriptionQueue {
    private let sessionStore: BLESessionStore
    private let eventEmitter: BikeBLEEventEmitter
    private let timeoutScheduler: any BikeBLETimeoutScheduling
    private let experimentalCaptureCoordinator: BikeBLEExperimentalCaptureCoordinator

    init(
        sessionStore: BLESessionStore,
        eventEmitter: BikeBLEEventEmitter,
        timeoutScheduler: any BikeBLETimeoutScheduling,
        experimentalCaptureCoordinator: BikeBLEExperimentalCaptureCoordinator
    ) {
        self.sessionStore = sessionStore
        self.eventEmitter = eventEmitter
        self.timeoutScheduler = timeoutScheduler
        self.experimentalCaptureCoordinator = experimentalCaptureCoordinator
    }

    func processNext(peripheral: CBPeripheral) async {
        if let characteristic = sessionStore.startNextUnsubscriptionCharacteristic() {
            scheduleTimeout(for: characteristic, isUnsubscription: true)
            await eventEmitter.send(.debug(.init(
                title: BikeSDKText.subscriptionTitle,
                detail: "Disabling \(characteristic.uuid.uuidString)"
            )))
            peripheral.setNotifyValue(false, for: characteristic)
            return
        }
        guard let characteristic = sessionStore.startNextNotificationCharacteristic() else { return }
        scheduleTimeout(for: characteristic, isUnsubscription: false)
        await eventEmitter.send(.debug(.init(
            title: BikeSDKText.subscriptionTitle,
            detail: "Enabling \(characteristic.uuid.uuidString)"
        )))
        peripheral.setNotifyValue(true, for: characteristic)
    }

    func reset() {
        timeoutScheduler.cancel()
    }

    func cancelTimeout() {
        timeoutScheduler.cancel()
    }

    private func scheduleTimeout(for characteristic: CBCharacteristic, isUnsubscription: Bool) {
        let uuid = characteristic.uuid
        timeoutScheduler.schedule { [weak self] in
            guard let self else { return }
            if isUnsubscription {
                await self.unsubscriptionDidTimeOut(characteristicUUID: uuid)
            } else {
                await self.subscriptionDidTimeOut(characteristicUUID: uuid)
            }
        }
    }

    func subscriptionDidTimeOut(characteristicUUID: CBUUID) async {
        guard sessionStore.completeActiveNotificationCharacteristic(matching: characteristicUUID) else {
            return
        }
        await eventEmitter.send(.error(.operationFailed(
            "Subscription timed out: \(characteristicUUID.uuidString)"
        )))
        guard let peripheral = sessionStore.peripheral else { return }
        await processNext(peripheral: peripheral)
        await experimentalCaptureCoordinator.advance(after: characteristicUUID, peripheral: peripheral)
    }

    private func unsubscriptionDidTimeOut(characteristicUUID: CBUUID) async {
        guard sessionStore.completeActiveUnsubscriptionCharacteristic(matching: characteristicUUID) else {
            return
        }
        await eventEmitter.send(.error(.operationFailed(
            "Unsubscription timed out: \(characteristicUUID.uuidString)"
        )))
        guard let peripheral = sessionStore.peripheral else { return }
        await processNext(peripheral: peripheral)
    }
}
