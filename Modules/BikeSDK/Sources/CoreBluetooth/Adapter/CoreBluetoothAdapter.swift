import CoreBluetooth

@MainActor
public protocol CoreBluetoothAdapter: AnyObject {
    var state: CBManagerState { get }
    func start(delegate: CBCentralManagerDelegate)
    func stopScan()
    func retrieveConnectedPeripherals(withServices serviceUUIDs: [CBUUID]) -> [CBPeripheral]
    func scanForBike()
    func connect(_ peripheral: CBPeripheral)
    func cancelConnection(_ peripheral: CBPeripheral)
}
