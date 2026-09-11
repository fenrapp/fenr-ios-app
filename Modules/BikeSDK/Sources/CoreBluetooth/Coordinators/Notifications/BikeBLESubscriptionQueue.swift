import CoreBluetooth

@MainActor
final class BikeBLESubscriptionQueue {
    private var timeoutGeneration = 0
    private let sessionStore: BLESessionStore
    private let eventEmitter: BikeBLEEventEmitter
    private let timeoutScheduler: any BikeBLETimeoutScheduling
    private let experimentalCaptureCoordinator: BikeBLEExperimentalCaptureCoordinator
    private let peripheralOperations: BikeBLEPeripheralOperations

    init(
        sessionStore: BLESessionStore,
        eventEmitter: BikeBLEEventEmitter,
        timeoutScheduler: any BikeBLETimeoutScheduling,
        experimentalCaptureCoordinator: BikeBLEExperimentalCaptureCoordinator,
        peripheralOperations: BikeBLEPeripheralOperations
    ) {
        self.sessionStore = sessionStore
        self.eventEmitter = eventEmitter
        self.timeoutScheduler = timeoutScheduler
        self.experimentalCaptureCoordinator = experimentalCaptureCoordinator
        self.peripheralOperations = peripheralOperations
    }

    func processNext(peripheral: CBPeripheral) async {
        if let characteristic = sessionStore.startNextUnsubscriptionCharacteristic() {
            scheduleTimeout(for: characteristic, isUnsubscription: true)
            await eventEmitter.sendDiagnostic(.debug(.init(
                title: BikeSDKText.subscriptionTitle,
                detail: "Disabling \(characteristic.uuid.uuidString)"
            )))
            await peripheralOperations.setNotifyValue(
                false,
                characteristic: characteristic,
                peripheral: peripheral
            )
            return
        }
        guard let characteristic = sessionStore.startNextNotificationCharacteristic() else { return }
        scheduleTimeout(for: characteristic, isUnsubscription: false)
        await eventEmitter.sendDiagnostic(.debug(.init(
            title: BikeSDKText.subscriptionTitle,
            detail: "Enabling \(characteristic.uuid.uuidString)"
        )))
        await peripheralOperations.setNotifyValue(
            true,
            characteristic: characteristic,
            peripheral: peripheral
        )
    }

    func reset() {
        cancelTimeout()
    }

    func cancelTimeout() {
        timeoutGeneration += 1
        timeoutScheduler.cancel()
    }

    func retrySubscriptionIfNeeded(_ characteristic: CBCharacteristic) {
        guard sessionStore.claimTelemetryRetry(for: characteristic.uuid, operation: .subscription) else { return }
        sessionStore.enqueueNotificationCharacteristic(characteristic)
    }

    private func scheduleTimeout(for characteristic: CBCharacteristic, isUnsubscription: Bool) {
        cancelTimeout()
        let uuid = characteristic.uuid
        let generation = sessionStore.generation
        let timeout = timeoutGeneration
        timeoutScheduler.schedule { [weak self] in
            guard let self, self.sessionStore.generation == generation,
                  self.timeoutGeneration == timeout else { return }
            if isUnsubscription {
                await self.unsubscriptionDidTimeOut(characteristicUUID: uuid)
            } else {
                await self.subscriptionDidTimeOut(characteristicUUID: uuid)
            }
        }
    }

    func subscriptionDidTimeOut(characteristicUUID: CBUUID) async {
        guard let characteristic = sessionStore.activeNotificationCharacteristic,
              sessionStore.completeActiveNotificationCharacteristic(matching: characteristicUUID) else {
            return
        }
        let generation = sessionStore.generation
        cancelTimeout()
        retrySubscriptionIfNeeded(characteristic)
        await eventEmitter.send(.error(.operationFailed(
            "Subscription timed out: \(characteristicUUID.uuidString)"
        )))
        guard sessionStore.generation == generation, let peripheral = sessionStore.peripheral else { return }
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
