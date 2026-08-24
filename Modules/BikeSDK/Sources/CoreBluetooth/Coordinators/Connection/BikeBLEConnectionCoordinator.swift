import CoreBluetooth
import StarkProtocol

@MainActor
public final class BikeBLEConnectionCoordinator {
    private let adapter: CoreBluetoothAdapter
    private let sessionStore: BLESessionStore
    private let eventEmitter: BikeBLEEventEmitter
    private let peripheralDelegate: CBPeripheralDelegate
    private let reconnectController: BikeBLEReconnectController
    private let scanner: BikeBLEConnectionScanner
    private let sessionResetHandler: @MainActor () -> Void
    private var isDiscoveringBikes = false

    init(
        adapter: CoreBluetoothAdapter,
        sessionStore: BLESessionStore,
        eventEmitter: BikeBLEEventEmitter,
        peripheralDelegate: CBPeripheralDelegate,
        reconnectController: BikeBLEReconnectController,
        scanner: BikeBLEConnectionScanner,
        sessionResetHandler: @escaping @MainActor () -> Void = {}
    ) {
        self.adapter = adapter
        self.sessionStore = sessionStore
        self.eventEmitter = eventEmitter
        self.peripheralDelegate = peripheralDelegate
        self.reconnectController = reconnectController
        self.scanner = scanner
        self.sessionResetHandler = sessionResetHandler
    }

    public func stop() async {
        reconnectController.reset()
        isDiscoveringBikes = false
        sessionStore.setReconnectIntent(false)
        adapter.stopScan()
        if let peripheral = sessionStore.peripheral {
            adapter.cancelConnection(peripheral)
        }
        resetSession()
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
        reconnectController.reset()
        isDiscoveringBikes = false
        sessionStore.setReconnectIntent(true)
        await eventEmitter.send(.debug(.init(
            title: "BLE",
            detail: "connect requested; target=\(maskedVIN(targetVIN)) state=\(scanner.centralStateDescription)"
        )))
        try await scanForConnection()
    }

    public func startBikeDiscovery() async {
        guard !sessionStore.shouldConnectWhenPoweredOn, sessionStore.peripheral == nil else { return }
        isDiscoveringBikes = true
        await eventEmitter.send(.debug(.init(
            title: "BLE",
            detail: "discovery requested; state=\(scanner.centralStateDescription)"
        )))
        await scanner.scanForDiscovery()
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
        reconnectController.reset()
        isDiscoveringBikes = false
        adapter.stopScan()
        if let peripheral = sessionStore.peripheral {
            adapter.cancelConnection(peripheral)
        }
        resetSession()
        await eventEmitter.send(.connection(.disconnected(reason: BikeSDKText.disconnectedByUser)))
    }

    public func centralDidUpdateState() async {
        await eventEmitter.send(.debug(.init(
            title: "BLE",
            detail: "central state \(scanner.centralStateDescription)"
        )))
        guard sessionStore.peripheral == nil else { return }
        if sessionStore.shouldConnectWhenPoweredOn {
            guard !reconnectController.hasPendingReconnect else { return }
            do {
                try await scanForConnection()
            } catch {
                return
            }
            return
        }

        guard isDiscoveringBikes else {
            await scanner.emitBluetoothAvailability()
            return
        }
        await scanner.scanForDiscovery()
    }

    public func restore(peripherals: [CBPeripheral]) async {
        await scanner.restore(peripherals: peripherals)
    }

    public func didDiscover(peripheral: CBPeripheral, name: String?, rssi: Int) async {
        await eventEmitter.send(.debug(.init(
            title: "Scan",
            detail: "\(name ?? "Unknown") \(rssi) dBm"
        )))
        if isDiscoveringBikes,
           let name,
           StarkPairingIdentity.isValidVIN(name) {
            await eventEmitter.send(.discoveredBike(.init(
                vin: StarkPairingIdentity.normalizedVIN(name),
                rssi: rssi
            )))
        }
        guard StarkPairingIdentity.matches(name, targetVIN: sessionStore.targetVIN) else { return }
        guard sessionStore.peripheral == nil else { return }
        await connect(peripheral: peripheral, name: name, rssi: rssi)
    }

    private func connect(peripheral: CBPeripheral, name: String?, rssi: Int?) async {
        reconnectController.cancelPending()
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
        reconnectController.reset()
        let name = peripheral.name
        await eventEmitter.send(.connection(.discovering(peripheralName: name)))
        peripheral.discoverServices(BikeSDKConstants.serviceUUIDs)
        peripheral.readRSSI()
    }

    public func didFailToConnect(_ peripheral: CBPeripheral, error: Error?) async {
        guard sessionStore.isActive(peripheral) else { return }
        let message = error?.localizedDescription ?? BikeSDKText.connectFailed
        await eventEmitter.send(.connection(.failed(message: message)))
        resetSession()
        await reconnectIfNeeded()
    }

    public func didDisconnect(_ peripheral: CBPeripheral, error: Error?) async {
        guard sessionStore.isActive(peripheral) else { return }
        await eventEmitter.send(.connection(.disconnected(reason: error?.localizedDescription)))
        resetSession()
        await reconnectIfNeeded()
    }

    private func scanForConnection() async throws {
        try await scanner.scanForConnection { [weak self] peripheral in
            await self?.connect(peripheral: peripheral, name: peripheral.name, rssi: nil)
        }
    }

    private func reconnectIfNeeded() async {
        guard sessionStore.shouldConnectWhenPoweredOn else { return }
        let didSchedule = await reconnectController.schedule(
            onScheduled: { [eventEmitter, sessionStore] attempt, maximumAttempts in
                await eventEmitter.send(.connection(.reconnecting(
                    vin: sessionStore.targetVIN,
                    attempt: attempt,
                    maximumAttempts: maximumAttempts
                )))
            },
            operation: { [weak self] in
                guard let self, self.sessionStore.shouldConnectWhenPoweredOn else { return }
                try? await self.scanForConnection()
            }
        )
        guard didSchedule else {
            sessionStore.setReconnectIntent(false)
            resetSession()
            await eventEmitter.send(.connection(.failed(
                message: "Reconnect attempts exhausted"
            )))
            return
        }
    }

    private func resetSession() {
        sessionResetHandler()
        sessionStore.resetSession()
    }

    private func maskedVIN(_ vin: String) -> String {
        guard vin.count > 4 else { return vin }
        return "...\(vin.suffix(4))"
    }
}
