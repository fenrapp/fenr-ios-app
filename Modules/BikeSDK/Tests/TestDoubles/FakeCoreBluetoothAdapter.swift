import BikeSDK
import CoreBluetooth

@MainActor
final class FakeCoreBluetoothAdapter: CoreBluetoothAdapter {
    var state: CBManagerState = .unknown
    private(set) var startCount = 0
    private(set) var stopScanCount = 0
    private(set) var scanCount = 0
    private(set) var retrieveConnectedPeripheralsCount = 0

    func start(delegate: CBCentralManagerDelegate) {
        startCount += 1
    }

    func stopScan() {
        stopScanCount += 1
    }

    func retrieveConnectedPeripherals(withServices serviceUUIDs: [CBUUID]) -> [CBPeripheral] {
        retrieveConnectedPeripheralsCount += 1
        return []
    }

    func scanForBike() {
        scanCount += 1
    }

    func connect(_ peripheral: CBPeripheral) {}
    func cancelConnection(_ peripheral: CBPeripheral) {}
}
