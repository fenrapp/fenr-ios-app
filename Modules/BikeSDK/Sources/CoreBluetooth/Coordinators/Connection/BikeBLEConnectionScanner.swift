import CoreBluetooth
import StarkProtocol

@MainActor
final class BikeBLEConnectionScanner {
    private let adapter: CoreBluetoothAdapter
    private let sessionStore: BLESessionStore
    private let eventEmitter: BikeBLEEventEmitter
    private let peripheralDelegate: CBPeripheralDelegate
    private let reconnectController: BikeBLEReconnectController
    private var pendingRestoredPeripherals: [CBPeripheral] = []

    init(
        adapter: CoreBluetoothAdapter,
        sessionStore: BLESessionStore,
        eventEmitter: BikeBLEEventEmitter,
        peripheralDelegate: CBPeripheralDelegate,
        reconnectController: BikeBLEReconnectController
    ) {
        self.adapter = adapter
        self.sessionStore = sessionStore
        self.eventEmitter = eventEmitter
        self.peripheralDelegate = peripheralDelegate
        self.reconnectController = reconnectController
    }

    var centralStateDescription: String {
        switch adapter.state {
        case .unknown: "unknown"
        case .resetting: "resetting"
        case .unsupported: "unsupported"
        case .unauthorized: "unauthorized"
        case .poweredOff: "poweredOff"
        case .poweredOn: "poweredOn"
        @unknown default: "unrecognized"
        }
    }

    func scanForConnection(
        connect: @escaping @MainActor (CBPeripheral) async -> Void
    ) async throws {
        switch adapter.state {
        case .poweredOn:
            adapter.stopScan()
            if await connectRetrievedPeripheral(connect: connect) {
                return
            }
            await eventEmitter.send(.connection(.scanning(vin: sessionStore.targetVIN)))
            await eventEmitter.send(.debug(.init(
                title: "BLE",
                detail: "scan started for \(maskedVIN(sessionStore.targetVIN))"
            )))
            adapter.scanForBike()
        case .poweredOff:
            await eventEmitter.send(.connection(.bluetoothPoweredOff))
        case .unauthorized:
            await eventEmitter.send(.connection(.bluetoothUnauthorized))
        case .unsupported, .resetting, .unknown:
            try await eventEmitter.fail(.bluetoothUnavailable)
        @unknown default:
            try await eventEmitter.fail(.bluetoothUnavailable)
        }
    }

    func scanForDiscovery() async {
        guard adapter.state == .poweredOn else {
            await emitBluetoothAvailability()
            return
        }
        await eventEmitter.send(.debug(.init(
            title: "BLE",
            detail: "discovery scan started"
        )))
        adapter.scanForBike()
    }

    func restore(peripherals: [CBPeripheral]) async {
        guard adapter.state == .poweredOn else {
            pendingRestoredPeripherals = peripherals
            return
        }
        pendingRestoredPeripherals.removeAll()
        guard sessionStore.peripheral == nil else { return }
        guard let peripheral = restoredPeripheral(from: peripherals) else { return }
        await eventEmitter.send(.debug(.init(
            title: "BLE",
            detail: "restored \(peripherals.count) peripheral(s)"
        )))
        let hasConnectionIntent = sessionStore.shouldConnectWhenPoweredOn || !sessionStore.targetVIN.isEmpty
        guard hasConnectionIntent || peripheral.state != .disconnected else {
            await eventEmitter.send(.debug(.init(
                title: "BLE",
                detail: "restored peripheral waiting for explicit connect"
            )))
            return
        }
        restoreIdentity(from: peripheral)
        sessionStore.setReconnectIntent(true)
        reconnectController.cancelPending()
        sessionStore.setPeripheral(peripheral)
        peripheral.delegate = peripheralDelegate
        await eventEmitter.send(.peripheral(name: peripheral.name, identifier: peripheral.identifier))
        await resume(peripheral: peripheral)
    }

    func resumePendingRestorationIfNeeded() async -> Bool {
        guard adapter.state == .poweredOn, !pendingRestoredPeripherals.isEmpty else { return false }
        let peripherals = pendingRestoredPeripherals
        pendingRestoredPeripherals.removeAll()
        await restore(peripherals: peripherals)
        return sessionStore.peripheral != nil
    }

    func emitBluetoothAvailability() async {
        switch adapter.state {
        case .poweredOn:
            await eventEmitter.send(.connection(.idle))
        case .poweredOff:
            await eventEmitter.send(.connection(.bluetoothPoweredOff))
        case .unauthorized:
            await eventEmitter.send(.connection(.bluetoothUnauthorized))
        case .unsupported, .resetting, .unknown:
            await eventEmitter.send(.connection(.bluetoothUnavailable))
        @unknown default:
            await eventEmitter.send(.connection(.bluetoothUnavailable))
        }
    }

    private func connectRetrievedPeripheral(
        connect: @escaping @MainActor (CBPeripheral) async -> Void
    ) async -> Bool {
        let peripherals = adapter.retrieveConnectedPeripherals(withServices: BikeSDKConstants.serviceUUIDs)
        await eventEmitter.send(.debug(.init(
            title: "BLE",
            detail: "retrieved connected peripherals: \(peripherals.count)"
        )))
        guard let peripheral = peripherals.first(where: {
            StarkPairingIdentity.matches($0.name, targetVIN: sessionStore.targetVIN)
        }) else {
            return false
        }
        await connect(peripheral)
        return true
    }

    private func restoredPeripheral(from peripherals: [CBPeripheral]) -> CBPeripheral? {
        if !sessionStore.targetVIN.isEmpty {
            return peripherals.first {
                StarkPairingIdentity.matches($0.name, targetVIN: sessionStore.targetVIN)
            }
        }
        return peripherals.first { peripheral in
            guard let name = peripheral.name else { return false }
            return StarkPairingIdentity.isValidVIN(name)
        } ?? peripherals.first
    }

    private func restoreIdentity(from peripheral: CBPeripheral) {
        guard sessionStore.targetVIN.isEmpty,
              let name = peripheral.name,
              StarkPairingIdentity.isValidVIN(name)
        else { return }
        sessionStore.setTargetVIN(StarkPairingIdentity.normalizedVIN(name))
    }

    private func resume(peripheral: CBPeripheral) async {
        switch peripheral.state {
        case .connected:
            await eventEmitter.send(.connection(.discovering(peripheralName: peripheral.name)))
            continueDiscovery(for: peripheral)
        case .connecting:
            await emitConnecting(peripheral)
        default:
            await emitConnecting(peripheral)
            adapter.connect(peripheral)
        }
    }

    private func emitConnecting(_ peripheral: CBPeripheral) async {
        await eventEmitter.send(.connection(.connecting(
            vin: sessionStore.targetVIN,
            peripheralName: peripheral.name
        )))
    }

    private func continueDiscovery(for peripheral: CBPeripheral) {
        guard let services = peripheral.services, !services.isEmpty else {
            peripheral.discoverServices(BikeSDKConstants.serviceUUIDs)
            peripheral.readRSSI()
            return
        }
        for service in services where BikeSDKConstants.serviceUUIDs.contains(service.uuid) {
            if let characteristics = service.characteristics, !characteristics.isEmpty {
                characteristics.forEach(sessionStore.setCharacteristic)
            } else {
                peripheral.discoverCharacteristics(
                    BikeSDKConstants.characteristicUUIDs(for: service.uuid),
                    for: service
                )
            }
        }
        peripheral.readRSSI()
    }

    private func maskedVIN(_ vin: String) -> String {
        guard vin.count > 4 else { return vin }
        return "...\(vin.suffix(4))"
    }
}
