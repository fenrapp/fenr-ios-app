import BLETraceDomain
import CoreBluetooth

@MainActor
public final class CoreBluetoothPeripheralDelegateProxy: NSObject, @preconcurrency CBPeripheralDelegate {
    private let sessionStore: BLESessionStore
    private let callbackQueue: BikeBLECallbackQueue
    private let discoveryCoordinator: BikeBLEDiscoveryCoordinator
    private let securityCoordinator: BikeBLESecurityCoordinator
    private let notificationCoordinator: BikeBLENotificationCoordinator
    private let traceEmitter: BikeBLETraceEmitter

    init(
        sessionStore: BLESessionStore,
        callbackQueue: BikeBLECallbackQueue,
        discoveryCoordinator: BikeBLEDiscoveryCoordinator,
        securityCoordinator: BikeBLESecurityCoordinator,
        notificationCoordinator: BikeBLENotificationCoordinator,
        traceEmitter: BikeBLETraceEmitter
    ) {
        self.sessionStore = sessionStore
        self.callbackQueue = callbackQueue
        self.discoveryCoordinator = discoveryCoordinator
        self.securityCoordinator = securityCoordinator
        self.notificationCoordinator = notificationCoordinator
        self.traceEmitter = traceEmitter
        super.init()
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        callbackQueue.enqueue { [sessionStore, discoveryCoordinator, traceEmitter] in
            guard sessionStore.isActive(peripheral) else { return }
            await traceEmitter.record(
                category: "gatt",
                operation: .servicesDiscovered,
                direction: .inbound,
                detail: peripheral.services?.map { $0.uuid.uuidString }.joined(separator: ","),
                error: error
            )
            await discoveryCoordinator.didDiscoverServices(peripheral: peripheral, error: error)
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        callbackQueue.enqueue { [sessionStore, discoveryCoordinator, traceEmitter] in
            guard sessionStore.isActive(peripheral) else { return }
            await traceEmitter.record(
                category: "gatt",
                operation: .characteristicsDiscovered,
                direction: .inbound,
                serviceUUID: service.uuid,
                detail: service.characteristics?.map {
                    "\($0.uuid.uuidString)[\($0.properties.protocolDescription)]"
                }.joined(separator: ","),
                error: error
            )
            await discoveryCoordinator.didDiscoverCharacteristics(
                peripheral: peripheral,
                service: service,
                error: error
            )
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        callbackQueue.enqueue { [sessionStore, securityCoordinator, notificationCoordinator, traceEmitter] in
            guard sessionStore.isActive(peripheral) else { return }
            await traceEmitter.record(
                category: "gatt",
                operation: .notificationStateUpdated,
                direction: .inbound,
                serviceUUID: characteristic.service?.uuid,
                characteristicUUID: characteristic.uuid,
                detail: characteristic.isNotifying ? "enabled" : "disabled",
                error: error
            )
            if securityCoordinator.handles(characteristic) {
                await securityCoordinator.didUpdateNotificationState(
                    peripheral: peripheral,
                    characteristic: characteristic,
                    error: error
                )
            } else {
                await notificationCoordinator.didUpdateNotificationState(
                    peripheral: peripheral,
                    characteristic: characteristic,
                    error: error
                )
            }
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverDescriptorsFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        callbackQueue.enqueue { [sessionStore, securityCoordinator, notificationCoordinator, traceEmitter] in
            guard sessionStore.isActive(peripheral) else { return }
            await traceEmitter.record(
                category: "gatt",
                operation: .descriptorsDiscovered,
                direction: .inbound,
                serviceUUID: characteristic.service?.uuid,
                characteristicUUID: characteristic.uuid,
                detail: characteristic.descriptors?.map { $0.uuid.uuidString }.joined(separator: ","),
                error: error
            )
            if securityCoordinator.handles(characteristic) {
                await securityCoordinator.didDiscoverDescriptors(
                    peripheral: peripheral,
                    characteristic: characteristic,
                    error: error
                )
            } else {
                await notificationCoordinator.didDiscoverDescriptors(
                    peripheral: peripheral,
                    characteristic: characteristic,
                    error: error
                )
            }
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        callbackQueue.enqueue { [sessionStore, securityCoordinator, notificationCoordinator, traceEmitter] in
            guard sessionStore.isActive(peripheral) else { return }
            await traceEmitter.recordValueUpdate(characteristic: characteristic, error: error)
            if securityCoordinator.handles(characteristic) {
                await securityCoordinator.didUpdateValue(
                    peripheral: peripheral,
                    characteristic: characteristic,
                    error: error
                )
            } else {
                await notificationCoordinator.didUpdateValue(
                    peripheral: peripheral,
                    characteristic: characteristic,
                    error: error
                )
            }
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        callbackQueue.enqueue { [sessionStore, securityCoordinator, notificationCoordinator, traceEmitter] in
            guard sessionStore.isActive(peripheral) else { return }
            await traceEmitter.record(
                category: "gatt",
                operation: .writeCompleted,
                direction: .inbound,
                serviceUUID: characteristic.service?.uuid,
                characteristicUUID: characteristic.uuid,
                error: error
            )
            if securityCoordinator.handles(characteristic) {
                await securityCoordinator.didWriteValue(characteristic: characteristic, error: error)
            } else {
                await notificationCoordinator.didWriteValue(characteristic: characteristic, error: error)
            }
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        callbackQueue.enqueue { [sessionStore, notificationCoordinator, traceEmitter] in
            guard sessionStore.isActive(peripheral) else { return }
            await traceEmitter.record(
                category: "link",
                operation: .rssiReceived,
                direction: .inbound,
                detail: "\(RSSI.intValue) dBm",
                error: error
            )
            await notificationCoordinator.didReadRSSI(RSSI.intValue, error: error)
        }
    }
}
