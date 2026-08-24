import CoreBluetooth

@MainActor
public final class CoreBluetoothCentralDelegateProxy: NSObject, @preconcurrency CBCentralManagerDelegate {
    private let connectionCoordinator: BikeBLEConnectionCoordinator
    private let callbackQueue: BikeBLECallbackQueue

    public init(
        connectionCoordinator: BikeBLEConnectionCoordinator,
        callbackQueue: BikeBLECallbackQueue
    ) {
        self.connectionCoordinator = connectionCoordinator
        self.callbackQueue = callbackQueue
        super.init()
    }

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        callbackQueue.enqueue { [connectionCoordinator] in
            await connectionCoordinator.centralDidUpdateState()
        }
    }

    public func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] ?? []
        callbackQueue.enqueue { [connectionCoordinator] in
            await connectionCoordinator.restore(peripherals: peripherals)
        }
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let name = advertisedName ?? peripheral.name
        callbackQueue.enqueue { [connectionCoordinator] in
            await connectionCoordinator.didDiscover(
                peripheral: peripheral,
                name: name,
                rssi: RSSI.intValue
            )
        }
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        callbackQueue.enqueue { [connectionCoordinator] in
            await connectionCoordinator.didConnect(peripheral)
        }
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        callbackQueue.enqueue { [connectionCoordinator] in
            await connectionCoordinator.didFailToConnect(peripheral, error: error)
        }
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        callbackQueue.enqueue { [connectionCoordinator] in
            await connectionCoordinator.didDisconnect(peripheral, error: error)
        }
    }
}
