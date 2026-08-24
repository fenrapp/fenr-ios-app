import CoreBluetooth
import RuntimeConfiguration

@MainActor
public protocol CoreBluetoothAdapter: AnyObject {
    var state: CBManagerState { get }
    func start(delegate: CBCentralManagerDelegate)
    func start(delegate: CBCentralManagerDelegate, restorationIdentifier: String?)
    func stopScan()
    func retrieveConnectedPeripherals(withServices serviceUUIDs: [CBUUID]) -> [CBPeripheral]
    func scanForBike()
    func connect(_ peripheral: CBPeripheral)
    func cancelConnection(_ peripheral: CBPeripheral)
}

public extension CoreBluetoothAdapter {
    func start(delegate: CBCentralManagerDelegate) {
        start(delegate: delegate, restorationIdentifier: nil)
    }
}
