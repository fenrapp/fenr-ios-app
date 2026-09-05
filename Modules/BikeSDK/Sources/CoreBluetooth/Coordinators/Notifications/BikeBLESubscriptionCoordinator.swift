import CoreBluetooth

@MainActor
struct BikeBLESubscriptionCoordinator {
    private let sessionStore: BLESessionStore
    private let eventEmitter: BikeBLEEventEmitter
    private let notificationPreparer: BikeBLENotificationPreparer
    private let experimentalCaptureCoordinator: BikeBLEExperimentalCaptureCoordinator
    private let queue: BikeBLESubscriptionQueue
    private let requiredSubscriptionsDidComplete: @MainActor () -> Void
    private let configSubscriptionDidComplete: @MainActor () -> Void

    init(
        sessionStore: BLESessionStore,
        eventEmitter: BikeBLEEventEmitter,
        notificationPreparer: BikeBLENotificationPreparer,
        experimentalCaptureCoordinator: BikeBLEExperimentalCaptureCoordinator,
        queue: BikeBLESubscriptionQueue,
        requiredSubscriptionsDidComplete: @escaping @MainActor () -> Void = {},
        configSubscriptionDidComplete: @escaping @MainActor () -> Void = {}
    ) {
        self.sessionStore = sessionStore
        self.eventEmitter = eventEmitter
        self.notificationPreparer = notificationPreparer
        self.experimentalCaptureCoordinator = experimentalCaptureCoordinator
        self.queue = queue
        self.requiredSubscriptionsDidComplete = requiredSubscriptionsDidComplete
        self.configSubscriptionDidComplete = configSubscriptionDidComplete
    }

    func prepareIfNeeded(characteristic: CBCharacteristic, peripheral: CBPeripheral) async {
        guard shouldPrepareNotification(for: characteristic) else { return }
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
        await eventEmitter.sendDiagnostic(.debug(.init(
            title: BikeSDKText.descriptorTitle,
            detail: "\(characteristicUUID) \(descriptorUUIDs ?? BikeSDKText.noDescriptors)"
        )))

        guard characteristic.hasClientConfigurationDescriptor else {
            await eventEmitter.send(.error(.operationFailed("Missing CCCD \(characteristicUUID)")))
            await experimentalCaptureCoordinator.advance(after: characteristic.uuid, peripheral: peripheral)
            return
        }
        guard shouldQueueNotification(for: characteristic) else {
            await experimentalCaptureCoordinator.advance(after: characteristic.uuid, peripheral: peripheral)
            return
        }
        sessionStore.enqueueNotificationCharacteristic(characteristic)
        guard sessionStore.authenticationState == .authenticated else {
            await eventEmitter.sendDiagnostic(.debug(.init(
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
                await eventEmitter.sendDiagnostic(.debug(.init(
                    title: BikeSDKText.subscriptionTitle,
                    detail: "Disabled \(characteristicUUID)"
                )))
            }
            await queue.processNext(peripheral: peripheral)
            return
        }
        guard sessionStore.completeActiveNotificationCharacteristic(matching: characteristic.uuid) else {
            await eventEmitter.sendDiagnostic(.debug(.init(
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
            await eventEmitter.sendDiagnostic(.debug(.init(
                title: BikeSDKText.subscriptionTitle,
                detail: "Not notifying \(characteristicUUID)"
            )))
            await queue.processNext(peripheral: peripheral)
            await experimentalCaptureCoordinator.advance(after: characteristic.uuid, peripheral: peripheral)
            return
        }
        await completeSubscription(characteristic: characteristic, restored: false)
        await queue.processNext(peripheral: peripheral)
        await experimentalCaptureCoordinator.advance(after: characteristic.uuid, peripheral: peripheral)
        await reportRequiredSubscriptionsIfNeeded(peripheral: peripheral, after: characteristic.uuid)
    }

    private func reportRequiredSubscriptionsIfNeeded(peripheral: CBPeripheral, after uuid: CBUUID) async {
        guard !sessionStore.hasReportedRequiredSubscriptions else { return }
        if sessionStore.markRequiredSubscriptionsCompleted(
            requiredUUIDs: BikeSDKConstants.requiredTelemetryNotifyUUIDs
        ) {
            BikePowerModeDebugLog.log("required telemetry subscriptions completed")
            let subscribed = BikeSDKConnectionStatus.subscribed(peripheralName: peripheral.name)
            if sessionStore.shouldPublishSubscribedConnectionState {
                await eventEmitter.send(.connection(subscribed))
            }
            requiredSubscriptionsDidComplete()
            await prepareConfigurationNotificationIfAvailable(peripheral: peripheral)
            return
        }
        let missing = BikeSDKConstants.requiredTelemetryNotifyUUIDs
            .filter { !sessionStore.subscribedCharacteristics.contains($0) }
            .map(\.uuidString)
            .joined(separator: ",")
        BikePowerModeDebugLog.log("subscription progress after \(uuid.uuidString); missing=\(missing)")
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
                await eventEmitter.sendDiagnostic(.debug(.init(
                    title: BikeSDKText.subscriptionTitle,
                    detail: "Battery dataset unavailable \(uuid.uuidString)"
                )))
                continue
            }
            await notificationPreparer.prepare(characteristic: characteristic, peripheral: peripheral)
        }
    }

    func startIMUMonitoring() async throws {
        guard let peripheral = sessionStore.peripheral else {
            throw BikeSDKError.operationFailed(BikeSDKText.noActivePeripheral)
        }
        guard sessionStore.authenticationState == .authenticated else {
            throw BikeSDKError.operationFailed(BikeSDKText.authenticationRequired)
        }
        guard sessionStore.acquireIMUMonitoringLease() else { return }
        guard let characteristic = sessionStore.discoveredCharacteristics[BikeSDKConstants.imuMonitoringUUID]
        else {
            _ = sessionStore.releaseIMUMonitoringLease()
            throw BikeSDKError.operationFailed("Bike IMU is unavailable")
        }
        await notificationPreparer.prepare(characteristic: characteristic, peripheral: peripheral)
    }

    func stopIMUMonitoring() async {
        guard sessionStore.releaseIMUMonitoringLease(),
              let peripheral = sessionStore.peripheral
        else {
            return
        }
        let uuid = BikeSDKConstants.imuMonitoringUUID
        sessionStore.removePendingNotificationCharacteristic(uuid: uuid)
        guard let characteristic = sessionStore.discoveredCharacteristics[uuid] else { return }
        sessionStore.enqueueUnsubscriptionCharacteristic(characteristic)
        await queue.processNext(peripheral: peripheral)
    }

    func stopBatteryHealthMonitoring() async {
        guard sessionStore.releaseBatteryHealthMonitoringLease(),
              let peripheral = sessionStore.peripheral
        else {
            return
        }
        for uuid in BikeSDKConstants.batteryHealthMonitoringUUIDs {
            guard !BikeSDKConstants.telemetryCharacteristicUUIDs.contains(uuid) else { continue }
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
}

private extension BikeBLESubscriptionCoordinator {
    func completeSubscription(characteristic: CBCharacteristic, restored: Bool) async {
        sessionStore.setSubscribed(characteristic.uuid)
        await eventEmitter.sendDiagnostic(.debug(.init(
            title: BikeSDKText.subscriptionTitle,
            detail: "Enabled \(characteristic.uuid.uuidString)\(restored ? " (restored)" : "")"
        )))
        BikePowerModeDebugLog.log(
            "subscription recorded uuid=\(characteristic.uuid.uuidString) restored=\(restored)"
        )
        if characteristic.uuid == BikeSDKConstants.vcuBikeConfigurationUUID {
            BikePowerModeDebugLog.log("4005 notification subscription enabled")
            configSubscriptionDidComplete()
        }
        if BikeSDKConstants.batteryHealthMonitoringUUIDs.contains(characteristic.uuid),
           !BikeSDKConstants.telemetryCharacteristicUUIDs.contains(characteristic.uuid),
           !sessionStore.isBatteryHealthMonitoringActive() {
            sessionStore.enqueueUnsubscriptionCharacteristic(characteristic)
        }
        if characteristic.uuid == BikeSDKConstants.imuMonitoringUUID,
           !sessionStore.isIMUMonitoringActive() {
            sessionStore.enqueueUnsubscriptionCharacteristic(characteristic)
        }
    }

    func prepareConfigurationNotificationIfAvailable(peripheral: CBPeripheral) async {
        guard let characteristic = sessionStore.discoveredCharacteristics[
            BikeSDKConstants.vcuBikeConfigurationUUID
        ] else {
            return
        }
        if characteristic.isNotifying {
            await completeSubscription(characteristic: characteristic, restored: true)
            return
        }
        await notificationPreparer.prepare(characteristic: characteristic, peripheral: peripheral)
    }

    func shouldPrepareNotification(for characteristic: CBCharacteristic) -> Bool {
        let uuid = characteristic.uuid
        return BikeSDKConstants.telemetryCharacteristicUUIDs.contains(uuid)
            || (uuid == BikeSDKConstants.imuMonitoringUUID && sessionStore.isIMUMonitoringActive())
            || (BikeSDKConstants.batteryHealthMonitoringUUIDs.contains(uuid)
                && sessionStore.isBatteryHealthMonitoringActive())
    }

    func shouldQueueNotification(for characteristic: CBCharacteristic) -> Bool {
        shouldPrepareNotification(for: characteristic)
            || characteristic.uuid == BikeSDKConstants.vcuBikeConfigurationUUID
            || (BikeSDKConstants.experimentalCaptureUUIDs.contains(characteristic.uuid)
                && sessionStore.hasStartedExperimentalCapture)
    }
}
