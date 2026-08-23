import CoreBluetooth
import StarkProtocol

@MainActor
public final class BikeBLEConnectionCoordinator {
    private let adapter: CoreBluetoothAdapter
    private let sessionStore: BLESessionStore
    private let eventEmitter: BikeBLEEventEmitter
    private let peripheralDelegate: CBPeripheralDelegate
    private let reconnectDelay: any BikeBLEReconnectDelaying
    private let reconnectPolicy: BikeBLEReconnectPolicy
    private var reconnectAttempt = 0
    private var isDiscoveringBikes = false

    public init(
        adapter: CoreBluetoothAdapter,
        sessionStore: BLESessionStore,
        eventEmitter: BikeBLEEventEmitter,
        peripheralDelegate: CBPeripheralDelegate,
        reconnectDelay: any BikeBLEReconnectDelaying,
        reconnectPolicy: BikeBLEReconnectPolicy
    ) {
        self.adapter = adapter
        self.sessionStore = sessionStore
        self.eventEmitter = eventEmitter
        self.peripheralDelegate = peripheralDelegate
        self.reconnectDelay = reconnectDelay
        self.reconnectPolicy = reconnectPolicy
    }

    public func stop() async {
        reconnectAttempt = 0
        isDiscoveringBikes = false
        sessionStore.setReconnectIntent(false)
        adapter.stopScan()
        if let peripheral = sessionStore.peripheral {
            adapter.cancelConnection(peripheral)
        }
        sessionStore.resetSession()
        await eventEmitter.send(.connection(.idle))
    }

    public func connect(to vin: String) async throws {
        let targetVIN = vin.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !targetVIN.isEmpty else {
            try await eventEmitter.fail(.emptyVIN)
            return
        }
        guard !sessionStore.shouldConnectWhenPoweredOn, sessionStore.peripheral == nil else {
            try await eventEmitter.fail(.operationFailed(BikeSDKText.connectionAlreadyActive))
            return
        }
        sessionStore.setTargetVIN(targetVIN)
        isDiscoveringBikes = false
        sessionStore.setReconnectIntent(true)
        reconnectAttempt = 0
        try await scanIfPossible()
    }

    public func startBikeDiscovery() async {
        guard !sessionStore.shouldConnectWhenPoweredOn, sessionStore.peripheral == nil else { return }
        guard adapter.state == .poweredOn else { return }
        isDiscoveringBikes = true
        adapter.scanForBike()
    }

    public func stopBikeDiscovery() async {
        guard isDiscoveringBikes else { return }
        isDiscoveringBikes = false
        adapter.stopScan()
    }

    public func disconnect() async throws {
        guard sessionStore.shouldConnectWhenPoweredOn || sessionStore.peripheral != nil else {
            try await eventEmitter.fail(.notStarted)
            return
        }
        sessionStore.setReconnectIntent(false)
        reconnectAttempt = 0
        isDiscoveringBikes = false
        adapter.stopScan()
        if let peripheral = sessionStore.peripheral {
            adapter.cancelConnection(peripheral)
        }
        sessionStore.resetSession()
        await eventEmitter.send(.connection(.disconnected(reason: BikeSDKText.disconnectedByUser)))
    }

    public func centralDidUpdateState() async {
        guard sessionStore.shouldConnectWhenPoweredOn else { return }
        do {
            try await scanIfPossible()
        } catch {
            return
        }
    }

    public func didDiscover(peripheral: CBPeripheral, name: String?, rssi: Int) async {
        if isDiscoveringBikes,
           let name,
           StarkPairingIdentity.isValidVIN(name) {
            await eventEmitter.send(.discoveredBike(.init(
                vin: StarkPairingIdentity.normalizedVIN(name),
                rssi: rssi
            )))
        }
        guard name == sessionStore.targetVIN else { return }
        guard sessionStore.peripheral == nil else { return }
        await connect(peripheral: peripheral, name: name, rssi: rssi)
    }

    private func connect(peripheral: CBPeripheral, name: String?, rssi: Int?) async {
        sessionStore.setPeripheral(peripheral)
        peripheral.delegate = peripheralDelegate

        let snapshot = BLEPeripheralSnapshot(name: name, identifier: peripheral.identifier, rssi: rssi)
        if let rssi = snapshot.rssi {
            await eventEmitter.send(.rssi(rssi))
        }
        await eventEmitter.send(.peripheral(name: snapshot.name, identifier: snapshot.identifier))
        await eventEmitter.send(.connection(.connecting(
            vin: sessionStore.targetVIN,
            peripheralName: snapshot.name
        )))
        adapter.stopScan()
        adapter.connect(peripheral)
    }

    public func didConnect(_ peripheral: CBPeripheral) async {
        guard sessionStore.isActive(peripheral) else { return }
        reconnectAttempt = 0
        let name = peripheral.name
        await eventEmitter.send(.connection(.discovering(peripheralName: name)))
        peripheral.discoverServices(BikeSDKConstants.serviceUUIDs)
        peripheral.readRSSI()
    }

    public func didFailToConnect(_ peripheral: CBPeripheral, error: Error?) async {
        guard sessionStore.isActive(peripheral) else { return }
        let message = error?.localizedDescription ?? BikeSDKText.connectFailed
        await eventEmitter.send(.connection(.failed(message: message)))
        await reconnectIfNeeded()
    }

    public func didDisconnect(_ peripheral: CBPeripheral, error: Error?) async {
        guard sessionStore.isActive(peripheral) else { return }
        await eventEmitter.send(.connection(.disconnected(reason: error?.localizedDescription)))
        sessionStore.resetSession()
        await reconnectIfNeeded()
    }

    private func scanIfPossible() async throws {
        switch adapter.state {
        case .poweredOn:
            adapter.stopScan()
            if await connectRetrievedPeripheralIfAvailable() {
                return
            }
            await eventEmitter.send(.connection(.scanning(vin: sessionStore.targetVIN)))
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

    private func connectRetrievedPeripheralIfAvailable() async -> Bool {
        let peripherals = adapter.retrieveConnectedPeripherals(withServices: BikeSDKConstants.serviceUUIDs)
        guard let peripheral = peripherals.first(where: { $0.name == sessionStore.targetVIN }) else {
            return false
        }
        await connect(peripheral: peripheral, name: peripheral.name, rssi: nil)
        return true
    }

    private func reconnectIfNeeded() async {
        guard sessionStore.shouldConnectWhenPoweredOn else { return }
        let nextAttempt = reconnectAttempt + 1
        guard let delay = reconnectPolicy.delay(forAttempt: nextAttempt) else {
            sessionStore.setReconnectIntent(false)
            sessionStore.resetSession()
            await eventEmitter.send(.connection(.failed(
                message: "Reconnect attempts exhausted"
            )))
            return
        }
        reconnectAttempt = nextAttempt
        sessionStore.resetSession()
        await eventEmitter.send(.connection(.reconnecting(
            vin: sessionStore.targetVIN,
            attempt: nextAttempt,
            maximumAttempts: reconnectPolicy.delays.count
        )))
        do {
            try await reconnectDelay.wait(for: delay)
        } catch {
            return
        }
        guard sessionStore.shouldConnectWhenPoweredOn else { return }
        do {
            try await scanIfPossible()
        } catch {
            return
        }
    }
}
