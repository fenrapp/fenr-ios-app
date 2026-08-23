import CoreBluetooth
import Foundation

@MainActor
public final class BikeBLENotificationCoordinator {
    let sessionStore: BLESessionStore
    let eventEmitter: BikeBLEEventEmitter
    private let notificationProcessor: BikeBLENotificationProcessor
    private let timeoutScheduler: any BikeBLETimeoutScheduling

    public init(
        sessionStore: BLESessionStore,
        eventEmitter: BikeBLEEventEmitter,
        notificationProcessor: BikeBLENotificationProcessor,
        timeoutScheduler: any BikeBLETimeoutScheduling
    ) {
        self.sessionStore = sessionStore
        self.eventEmitter = eventEmitter
        self.notificationProcessor = notificationProcessor
        self.timeoutScheduler = timeoutScheduler
    }

    public func discovered(characteristic: CBCharacteristic, peripheral: CBPeripheral) async {
        sessionStore.setCharacteristic(characteristic)
        await eventEmitter.send(.debug(.init(
            title: BikeSDKText.characteristicTitle,
            detail: "\(characteristic.uuid.uuidString) \(characteristic.properties.protocolDescription)"
        )))
        guard shouldPrepareNotification(for: characteristic.uuid) else { return }
        await prepareNotification(characteristic: characteristic, peripheral: peripheral)
    }

    public func didDiscoverDescriptors(
        peripheral: CBPeripheral,
        characteristic: CBCharacteristic,
        error: Error?
    ) async {
        let characteristicUUID = characteristic.uuid.uuidString
        if let error {
            let message = "Descriptor discovery failed \(characteristicUUID): \(error.localizedDescription)"
            await eventEmitter.send(.error(.operationFailed(message)))
            await advanceExperimentalCapture(after: characteristic, peripheral: peripheral)
            return
        }

        let descriptorUUIDs = characteristic.descriptors?.map(\.uuid.uuidString).joined(separator: ",")
        await eventEmitter.send(.debug(.init(
            title: BikeSDKText.descriptorTitle,
            detail: "\(characteristicUUID) \(descriptorUUIDs ?? BikeSDKText.noDescriptors)"
        )))

        guard characteristic.hasClientConfigurationDescriptor else {
            await eventEmitter.send(.error(.operationFailed("Missing CCCD \(characteristicUUID)")))
            await advanceExperimentalCapture(after: characteristic, peripheral: peripheral)
            return
        }

        guard shouldQueueNotification(for: characteristic.uuid) else {
            await advanceExperimentalCapture(after: characteristic, peripheral: peripheral)
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
        await processNextNotificationOperation(peripheral: peripheral)
    }

    public func didUpdateNotificationState(
        peripheral: CBPeripheral,
        characteristic: CBCharacteristic,
        error: Error?
    ) async {
        let characteristicUUID = characteristic.uuid.uuidString
        if sessionStore.completeActiveUnsubscriptionCharacteristic(matching: characteristic.uuid) {
            timeoutScheduler.cancel()
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
            await processNextNotificationOperation(peripheral: peripheral)
            return
        }
        guard sessionStore.completeActiveNotificationCharacteristic(matching: characteristic.uuid) else {
            await eventEmitter.send(.debug(.init(
                title: BikeSDKText.subscriptionTitle,
                detail: "\(BikeSDKText.unexpectedNotificationState): \(characteristicUUID)"
            )))
            return
        }
        timeoutScheduler.cancel()
        if let error {
            let message = "Subscribe failed \(characteristicUUID): \(error.localizedDescription)"
            await eventEmitter.send(.error(.operationFailed(message)))
            await processNextNotificationOperation(peripheral: peripheral)
            await advanceExperimentalCapture(after: characteristic, peripheral: peripheral)
            return
        }
        guard characteristic.isNotifying else {
            await eventEmitter.send(.debug(.init(
                title: BikeSDKText.subscriptionTitle,
                detail: "Not notifying \(characteristicUUID)"
            )))
            await processNextNotificationOperation(peripheral: peripheral)
            await advanceExperimentalCapture(after: characteristic, peripheral: peripheral)
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
        await processNextNotificationOperation(peripheral: peripheral)
        await advanceExperimentalCapture(after: characteristic, peripheral: peripheral)
        if sessionStore.markRequiredSubscriptionsCompleted(
            requiredUUIDs: BikeSDKConstants.requiredTelemetryNotifyUUIDs
        ) {
            let name = peripheral.name
            await eventEmitter.send(.connection(.subscribed(peripheralName: name)))
            await startExperimentalCapture(peripheral: peripheral)
        }
    }

    public func didUpdateValue(peripheral: CBPeripheral, characteristic: CBCharacteristic, error: Error?) async {
        let characteristicUUIDString = characteristic.uuid.uuidString
        if let error {
            let message = "Value update failed \(characteristicUUIDString): \(error.localizedDescription)"
            await eventEmitter.send(.error(.operationFailed(message)))
            return
        }
        guard let data = characteristic.value else { return }
        let uuid = characteristic.uuid.foundationUUID
        let date = Date()
        if let dataset = BikeSDKConstants.batteryDataset(for: characteristic.uuid) {
            await eventEmitter.send(.batteryDatasetCapture(.init(
                dataset: dataset,
                byteCount: data.count,
                hex: data.bikeSDKHexString,
                date: date
            )))
        }
        let didDecodeTelemetry = await notificationProcessor.process(characteristic: uuid, data: data, date: date)
        if didDecodeTelemetry, sessionStore.markTelemetryReceived(
            characteristicUUID: characteristic.uuid,
            requiredCharacteristicUUIDs: BikeSDKConstants.requiredTelemetryNotifyUUIDs
        ) {
            await eventEmitter.send(.connection(.receivingTelemetry(peripheralName: peripheral.name)))
        }
    }

    public func didReadRSSI(_ rssi: Int, error: Error?) async {
        guard error == nil else { return }
        await eventEmitter.send(.rssi(rssi))
    }

    public func authenticationDidSucceed(peripheral: CBPeripheral) async {
        notificationProcessor.resetDebugSampling()
        await processNextNotificationOperation(peripheral: peripheral)
    }

    public func readTelemetrySnapshot() async throws {
        guard let peripheral = sessionStore.peripheral else {
            await sendReadFailure(BikeSDKText.noActivePeripheral)
            throw BikeSDKError.operationFailed(BikeSDKText.noActivePeripheral)
        }

        guard sessionStore.authenticationState == .authenticated else {
            await sendReadFailure(BikeSDKText.authenticationRequired)
            throw BikeSDKError.operationFailed(BikeSDKText.authenticationRequired)
        }

        guard let characteristic = telemetryReadCandidate() else {
            await sendReadFailure(BikeSDKText.noReadableCharacteristics)
            throw BikeSDKError.operationFailed(BikeSDKText.noReadableCharacteristics)
        }

        await eventEmitter.send(.debug(.init(
            title: BikeSDKText.readTitle,
            detail: "\(BikeSDKText.manualSOCRead) \(characteristic.uuid.uuidString)"
        )))
        peripheral.readValue(for: characteristic)
    }

    public func readBikeStatusSnapshot() async throws {
        guard let peripheral = sessionStore.peripheral else {
            await sendReadFailure(BikeSDKText.noActivePeripheral)
            throw BikeSDKError.operationFailed(BikeSDKText.noActivePeripheral)
        }

        guard sessionStore.authenticationState == .authenticated else {
            await sendReadFailure(BikeSDKText.authenticationRequired)
            throw BikeSDKError.operationFailed(BikeSDKText.authenticationRequired)
        }

        guard let characteristic = statusReadCandidate() else {
            await sendReadFailure(BikeSDKText.noReadableCharacteristics)
            throw BikeSDKError.operationFailed(BikeSDKText.noReadableCharacteristics)
        }

        peripheral.readValue(for: characteristic)
    }

    private func telemetryReadCandidate() -> CBCharacteristic? {
        sessionStore.discoveredCharacteristics[BikeSDKConstants.batterySOCCharacteristicUUID]
            .flatMap { $0.properties.contains(.read) ? $0 : nil }
    }

    private func statusReadCandidate() -> CBCharacteristic? {
        sessionStore.discoveredCharacteristics[BikeSDKConstants.bikeStatusCharacteristicUUID]
            .flatMap { $0.properties.contains(.read) ? $0 : nil }
    }

    func processNextNotificationOperation(peripheral: CBPeripheral) async {
        if let characteristic = sessionStore.startNextUnsubscriptionCharacteristic() {
            let characteristicUUID = characteristic.uuid
            timeoutScheduler.schedule { [weak self] in
                await self?.unsubscriptionDidTimeOut(characteristicUUID: characteristicUUID)
            }
            await eventEmitter.send(.debug(.init(
                title: BikeSDKText.subscriptionTitle,
                detail: "Disabling \(characteristic.uuid.uuidString)"
            )))
            peripheral.setNotifyValue(false, for: characteristic)
            return
        }
        guard let characteristic = sessionStore.startNextNotificationCharacteristic() else { return }
        let characteristicUUID = characteristic.uuid
        timeoutScheduler.schedule { [weak self] in
            await self?.subscriptionDidTimeOut(characteristicUUID: characteristicUUID)
        }
        await eventEmitter.send(.debug(.init(
            title: BikeSDKText.subscriptionTitle,
            detail: "Enabling \(characteristic.uuid.uuidString)"
        )))
        peripheral.setNotifyValue(true, for: characteristic)
    }

    func subscriptionDidTimeOut(characteristicUUID: CBUUID) async {
        guard sessionStore.completeActiveNotificationCharacteristic(matching: characteristicUUID) else {
            return
        }
        await eventEmitter.send(.error(.operationFailed(
            "Subscription timed out: \(characteristicUUID.uuidString)"
        )))
        guard let peripheral = sessionStore.peripheral else { return }
        await processNextNotificationOperation(peripheral: peripheral)
        await advanceExperimentalCapture(after: characteristicUUID, peripheral: peripheral)
    }

    private func unsubscriptionDidTimeOut(characteristicUUID: CBUUID) async {
        guard sessionStore.completeActiveUnsubscriptionCharacteristic(matching: characteristicUUID) else {
            return
        }
        await eventEmitter.send(.error(.operationFailed(
            "Unsubscription timed out: \(characteristicUUID.uuidString)"
        )))
        guard let peripheral = sessionStore.peripheral else { return }
        await processNextNotificationOperation(peripheral: peripheral)
    }

    private func sendReadFailure(_ message: String) async {
        await eventEmitter.send(.error(.operationFailed(message)))
    }
}
