import CoreBluetooth

@MainActor
public final class AppleCoreBluetoothAdapter: CoreBluetoothAdapter {
    private var central: CBCentralManager?

    public var state: CBManagerState {
        central?.state ?? .unknown
    }

    public init() {}

    public func start(delegate: CBCentralManagerDelegate) {
        guard central == nil else { return }
        central = CBCentralManager(delegate: delegate, queue: .main)
    }

    public func stopScan() {
        central?.stopScan()
    }

    public func retrieveConnectedPeripherals(withServices serviceUUIDs: [CBUUID]) -> [CBPeripheral] {
        central?.retrieveConnectedPeripherals(withServices: serviceUUIDs) ?? []
    }

    public func scanForBike() {
        central?.scanForPeripherals(withServices: nil, options: BikeSDKConstants.scanOptions)
    }

    public func connect(_ peripheral: CBPeripheral) {
        central?.connect(peripheral)
    }

    public func cancelConnection(_ peripheral: CBPeripheral) {
        central?.cancelPeripheralConnection(peripheral)
    }
}
