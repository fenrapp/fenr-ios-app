import CoreBluetooth

@MainActor
public final class CoreBluetoothPeripheralDelegateProxy: NSObject, @preconcurrency CBPeripheralDelegate {
    private let sessionStore: BLESessionStore
    private let callbackQueue: BikeBLECallbackQueue
    private let discoveryCoordinator: BikeBLEDiscoveryCoordinator
    private let securityCoordinator: BikeBLESecurityCoordinator
    private let notificationCoordinator: BikeBLENotificationCoordinator

    public init(
        sessionStore: BLESessionStore,
        callbackQueue: BikeBLECallbackQueue,
        discoveryCoordinator: BikeBLEDiscoveryCoordinator,
        securityCoordinator: BikeBLESecurityCoordinator,
        notificationCoordinator: BikeBLENotificationCoordinator
    ) {
        self.sessionStore = sessionStore
        self.callbackQueue = callbackQueue
        self.discoveryCoordinator = discoveryCoordinator
        self.securityCoordinator = securityCoordinator
        self.notificationCoordinator = notificationCoordinator
        super.init()
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        callbackQueue.enqueue { [sessionStore, discoveryCoordinator] in
            guard sessionStore.isActive(peripheral) else { return }
            await discoveryCoordinator.didDiscoverServices(peripheral: peripheral, error: error)
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        callbackQueue.enqueue { [sessionStore, discoveryCoordinator] in
            guard sessionStore.isActive(peripheral) else { return }
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
        callbackQueue.enqueue { [sessionStore, securityCoordinator, notificationCoordinator] in
            guard sessionStore.isActive(peripheral) else { return }
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
        callbackQueue.enqueue { [sessionStore, securityCoordinator, notificationCoordinator] in
            guard sessionStore.isActive(peripheral) else { return }
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
        callbackQueue.enqueue { [sessionStore, securityCoordinator, notificationCoordinator] in
            guard sessionStore.isActive(peripheral) else { return }
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
        callbackQueue.enqueue { [sessionStore, securityCoordinator] in
            guard sessionStore.isActive(peripheral) else { return }
            await securityCoordinator.didWriteValue(characteristic: characteristic, error: error)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        callbackQueue.enqueue { [sessionStore, notificationCoordinator] in
            guard sessionStore.isActive(peripheral) else { return }
            await notificationCoordinator.didReadRSSI(RSSI.intValue, error: error)
        }
    }
}
