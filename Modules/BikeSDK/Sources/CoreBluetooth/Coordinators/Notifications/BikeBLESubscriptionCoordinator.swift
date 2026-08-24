import CoreBluetooth

@MainActor
struct BikeBLESubscriptionCoordinator {
    private let sessionStore: BLESessionStore
    private let eventEmitter: BikeBLEEventEmitter
    private let notificationPreparer: BikeBLENotificationPreparer
    private let experimentalCaptureCoordinator: BikeBLEExperimentalCaptureCoordinator
    private let queue: BikeBLESubscriptionQueue

    init(
        sessionStore: BLESessionStore,
        eventEmitter: BikeBLEEventEmitter,
        notificationPreparer: BikeBLENotificationPreparer,
        experimentalCaptureCoordinator: BikeBLEExperimentalCaptureCoordinator,
        queue: BikeBLESubscriptionQueue
    ) {
        self.sessionStore = sessionStore
        self.eventEmitter = eventEmitter
        self.notificationPreparer = notificationPreparer
        self.experimentalCaptureCoordinator = experimentalCaptureCoordinator
        self.queue = queue
    }

    func prepareIfNeeded(characteristic: CBCharacteristic, peripheral: CBPeripheral) async {
        guard shouldPrepareNotification(for: characteristic.uuid) else { return }
        await notificationPreparer.prepare(characteristic: characteristic, peripheral: peripheral)
    }

    func didDiscoverDescriptors(
        peripheral: CBPeripheral,
        characteristic: CBCharacteristic,
        error: Error?
    ) async {
        let characteristicUUID = characteristic.uuid.uuidString
        if let error {
            await eventEmitter.send(.error(.operationFailed(
                "Descriptor discovery failed \(characteristicUUID): \(error.localizedDescription)"
            )))
            await experimentalCaptureCoordinator.advance(after: characteristic.uuid, peripheral: peripheral)
            return
        }

        let descriptorUUIDs = characteristic.descriptors?.map(\.uuid.uuidString).joined(separator: ",")
        await eventEmitter.send(.debug(.init(
            title: BikeSDKText.descriptorTitle,
            detail: "\(characteristicUUID) \(descriptorUUIDs ?? BikeSDKText.noDescriptors)"
        )))

        guard characteristic.hasClientConfigurationDescriptor else {
            await eventEmitter.send(.error(.operationFailed("Missing CCCD \(characteristicUUID)")))
            await experimentalCaptureCoordinator.advance(after: characteristic.uuid, peripheral: peripheral)
            return
        }
        guard shouldQueueNotification(for: characteristic.uuid) else {
            await experimentalCaptureCoordinator.advance(after: characteristic.uuid, peripheral: peripheral)
            return
        }
        sessionStore.enqueueNotificationCharacteristic(characteristic)
        guard sessionStore.authenticationState == .authenticated else {
            await eventEmitter.send(.debug(.init(
                title: BikeSDKText.subscriptionTitle,
                detail: BikeSDKText.telemetryQueued
            )))
            return
        }
        await queue.processNext(peripheral: peripheral)
    }

    func didUpdateNotificationState(
        peripheral: CBPeripheral,
        characteristic: CBCharacteristic,
        error: Error?
    ) async {
        let characteristicUUID = characteristic.uuid.uuidString
        if sessionStore.completeActiveUnsubscriptionCharacteristic(matching: characteristic.uuid) {
            queue.cancelTimeout()
            if let error {
                await eventEmitter.send(.error(.operationFailed(
                    "Unsubscribe failed \(characteristicUUID): \(error.localizedDescription)"
                )))
            } else {
                sessionStore.removeSubscribed(characteristic.uuid)
                await eventEmitter.send(.debug(.init(
                    title: BikeSDKText.subscriptionTitle,
                    detail: "Disabled \(characteristicUUID)"
                )))
            }
            await queue.processNext(peripheral: peripheral)
            return
        }
        guard sessionStore.completeActiveNotificationCharacteristic(matching: characteristic.uuid) else {
            await eventEmitter.send(.debug(.init(
                title: BikeSDKText.subscriptionTitle,
                detail: "\(BikeSDKText.unexpectedNotificationState): \(characteristicUUID)"
            )))
            return
        }
        queue.cancelTimeout()
        if let error {
            await eventEmitter.send(.error(.operationFailed(
                "Subscribe failed \(characteristicUUID): \(error.localizedDescription)"
            )))
            await queue.processNext(peripheral: peripheral)
            await experimentalCaptureCoordinator.advance(after: characteristic.uuid, peripheral: peripheral)
            return
        }
        guard characteristic.isNotifying else {
            await eventEmitter.send(.debug(.init(
                title: BikeSDKText.subscriptionTitle,
                detail: "Not notifying \(characteristicUUID)"
            )))
            await queue.processNext(peripheral: peripheral)
            await experimentalCaptureCoordinator.advance(after: characteristic.uuid, peripheral: peripheral)
            return
        }
        sessionStore.setSubscribed(characteristic.uuid)
        await eventEmitter.send(.debug(.init(
            title: BikeSDKText.subscriptionTitle,
            detail: "Enabled \(characteristicUUID)"
        )))
        if BikeSDKConstants.batteryHealthMonitoringUUIDs.contains(characteristic.uuid),
           !sessionStore.isBatteryHealthMonitoringActive() {
            sessionStore.enqueueUnsubscriptionCharacteristic(characteristic)
        }
        await queue.processNext(peripheral: peripheral)
        await experimentalCaptureCoordinator.advance(after: characteristic.uuid, peripheral: peripheral)
        if sessionStore.markRequiredSubscriptionsCompleted(
            requiredUUIDs: BikeSDKConstants.requiredTelemetryNotifyUUIDs
        ) {
            await eventEmitter.send(.connection(.subscribed(peripheralName: peripheral.name)))
            await experimentalCaptureCoordinator.start(peripheral: peripheral)
        }
    }

    func authenticationDidSucceed(peripheral: CBPeripheral) async {
        await queue.processNext(peripheral: peripheral)
    }

    func startBatteryHealthMonitoring() async throws {
        guard let peripheral = sessionStore.peripheral else {
            throw BikeSDKError.operationFailed(BikeSDKText.noActivePeripheral)
        }
        guard sessionStore.authenticationState == .authenticated else {
            throw BikeSDKError.operationFailed(BikeSDKText.authenticationRequired)
        }
        guard sessionStore.acquireBatteryHealthMonitoringLease() else { return }

        for uuid in BikeSDKConstants.batteryHealthMonitoringUUIDs {
            guard let characteristic = sessionStore.discoveredCharacteristics[uuid] else {
                await eventEmitter.send(.debug(.init(
                    title: BikeSDKText.subscriptionTitle,
                    detail: "Battery dataset unavailable \(uuid.uuidString)"
                )))
                continue
            }
            await notificationPreparer.prepare(characteristic: characteristic, peripheral: peripheral)
        }
    }

    func stopBatteryHealthMonitoring() async {
        guard sessionStore.releaseBatteryHealthMonitoringLease(),
              let peripheral = sessionStore.peripheral
        else {
            return
        }
        for uuid in BikeSDKConstants.batteryHealthMonitoringUUIDs {
            sessionStore.removePendingNotificationCharacteristic(uuid: uuid)
            guard let characteristic = sessionStore.discoveredCharacteristics[uuid] else { continue }
            sessionStore.enqueueUnsubscriptionCharacteristic(characteristic)
        }
        await queue.processNext(peripheral: peripheral)
    }

    func subscriptionDidTimeOut(characteristicUUID: CBUUID) async {
        await queue.subscriptionDidTimeOut(characteristicUUID: characteristicUUID)
    }

    func reset() { queue.reset() }

    private func shouldPrepareNotification(for uuid: CBUUID) -> Bool {
        BikeSDKConstants.telemetryCharacteristicUUIDs.contains(uuid)
            || (BikeSDKConstants.batteryHealthMonitoringUUIDs.contains(uuid)
                && sessionStore.isBatteryHealthMonitoringActive())
    }

    private func shouldQueueNotification(for uuid: CBUUID) -> Bool {
        shouldPrepareNotification(for: uuid)
            || (BikeSDKConstants.experimentalCaptureUUIDs.contains(uuid)
                && sessionStore.hasStartedExperimentalCapture)
    }

}
