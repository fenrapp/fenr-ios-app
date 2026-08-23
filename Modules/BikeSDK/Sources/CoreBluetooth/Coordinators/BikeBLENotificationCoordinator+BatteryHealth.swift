import CoreBluetooth

extension BikeBLENotificationCoordinator {
    public func startBatteryHealthMonitoring() async throws {
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
            await prepareNotification(characteristic: characteristic, peripheral: peripheral)
        }
    }

    public func stopBatteryHealthMonitoring() async {
        guard sessionStore.releaseBatteryHealthMonitoringLease(), let peripheral = sessionStore.peripheral else {
            return
        }
        for uuid in BikeSDKConstants.batteryHealthMonitoringUUIDs {
            sessionStore.removePendingNotificationCharacteristic(uuid: uuid)
            guard let characteristic = sessionStore.discoveredCharacteristics[uuid] else { continue }
            sessionStore.enqueueUnsubscriptionCharacteristic(characteristic)
        }
        await processNextNotificationOperation(peripheral: peripheral)
    }

    func prepareNotification(characteristic: CBCharacteristic, peripheral: CBPeripheral) async {
        guard characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) else {
            let message = "\(BikeSDKText.telemetryNotifyUnavailable): \(characteristic.uuid.uuidString)"
            await eventEmitter.send(.error(.operationFailed(message)))
            return
        }
        peripheral.discoverDescriptors(for: characteristic)
    }

    func shouldPrepareNotification(for uuid: CBUUID) -> Bool {
        BikeSDKConstants.telemetryCharacteristicUUIDs.contains(uuid)
            || (BikeSDKConstants.batteryHealthMonitoringUUIDs.contains(uuid)
                && sessionStore.isBatteryHealthMonitoringActive())
    }

    func shouldQueueNotification(for uuid: CBUUID) -> Bool {
        shouldPrepareNotification(for: uuid)
            || (BikeSDKConstants.experimentalCaptureUUIDs.contains(uuid)
                && sessionStore.hasStartedExperimentalCapture)
    }

    func startExperimentalCapture(peripheral: CBPeripheral) async {
        guard sessionStore.authenticationState == .authenticated,
              sessionStore.markExperimentalCaptureStarted()
        else {
            return
        }

        await eventEmitter.send(.debug(.init(
            title: BikeSDKText.subscriptionTitle,
            detail: "Starting experimental capture after baseline telemetry"
        )))
        for uuid in BikeSDKConstants.experimentalCaptureUUIDs {
            guard let characteristic = sessionStore.discoveredCharacteristics[uuid] else { continue }
            sessionStore.enqueueExperimentalCaptureCharacteristic(characteristic)
        }
        await processNextExperimentalCapture(peripheral: peripheral)
    }

    func processNextExperimentalCapture(peripheral: CBPeripheral) async {
        guard let characteristic = sessionStore.startNextExperimentalCaptureCharacteristic() else { return }
        await eventEmitter.send(.debug(.init(
            title: BikeSDKText.subscriptionTitle,
            detail: "Preparing experimental capture " + characteristic.uuid.uuidString
        )))
        await prepareNotification(characteristic: characteristic, peripheral: peripheral)
    }

    func advanceExperimentalCapture(
        after characteristic: CBCharacteristic,
        peripheral: CBPeripheral
    ) async {
        await advanceExperimentalCapture(after: characteristic.uuid, peripheral: peripheral)
    }

    func advanceExperimentalCapture(after uuid: CBUUID, peripheral: CBPeripheral) async {
        guard sessionStore.completeActiveExperimentalCaptureCharacteristic(matching: uuid) else {
            return
        }
        await processNextExperimentalCapture(peripheral: peripheral)
    }
}
