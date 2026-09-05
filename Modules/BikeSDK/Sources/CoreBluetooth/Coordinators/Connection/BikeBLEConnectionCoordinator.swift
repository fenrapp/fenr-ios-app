import BLETraceDomain
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
    private let connectionErrorClassifier: BikeBLEConnectionErrorClassifier
    private let connectionWatchdog: BikeBLEConnectionWatchdog
    private let traceEmitter: BikeBLETraceEmitter
    private let peripheralOperations: BikeBLEPeripheralOperations
    private var isDiscoveringBikes = false

    init(
        adapter: CoreBluetoothAdapter,
        sessionStore: BLESessionStore,
        eventEmitter: BikeBLEEventEmitter,
        peripheralDelegate: CBPeripheralDelegate,
        reconnectController: BikeBLEReconnectController,
        scanner: BikeBLEConnectionScanner,
        connectionErrorClassifier: BikeBLEConnectionErrorClassifier,
        connectionWatchdog: BikeBLEConnectionWatchdog,
        sessionResetHandler: @escaping @MainActor () -> Void,
        traceEmitter: BikeBLETraceEmitter,
        peripheralOperations: BikeBLEPeripheralOperations
    ) {
        self.adapter = adapter
        self.sessionStore = sessionStore
        self.eventEmitter = eventEmitter
        self.peripheralDelegate = peripheralDelegate
        self.reconnectController = reconnectController
        self.scanner = scanner
        self.connectionErrorClassifier = connectionErrorClassifier
        self.connectionWatchdog = connectionWatchdog
        self.sessionResetHandler = sessionResetHandler
        self.traceEmitter = traceEmitter
        self.peripheralOperations = peripheralOperations
    }

    public func stop() async {
        reconnectController.reset()
        isDiscoveringBikes = false
        sessionStore.setReconnectIntent(false)
        await stopScan(reason: "client_stopped")
        if let peripheral = sessionStore.peripheral {
            await traceEmitter.record(
                category: "link",
                operation: .disconnectRequested,
                direction: .outbound,
                detail: "client_stopped"
            )
            adapter.cancelConnection(peripheral)
        }
        resetSession()
        await eventEmitter.send(.connection(.idle))
        await traceEmitter.finishSession(reason: .clientStopped)
    }

    public func startNewDiagnosticsCapture(vin: String) async -> Bool {
        await traceEmitter.startNewCapture(vin: vin)
    }

    public func stopDiagnosticsCapture() async -> Bool {
        await traceEmitter.stopCapture()
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
        await traceEmitter.selectBike(vin: targetVIN)
        await traceEmitter.record(
            category: "link",
            operation: .connectRequested,
            direction: .outbound,
            detail: "connection_intent_started"
        )
        sessionStore.setTargetVIN(targetVIN)
        reconnectController.reset()
        isDiscoveringBikes = false
        sessionStore.setReconnectIntent(true)
        await eventEmitter.sendDiagnostic(.debug(.init(
            title: "BLE",
            detail: "connect requested; target=\(maskedVIN(targetVIN)) state=\(scanner.centralStateDescription)"
        )))
        try await scanForConnection()
    }

    public func startBikeDiscovery() async {
        guard !sessionStore.shouldConnectWhenPoweredOn, sessionStore.peripheral == nil else { return }
        isDiscoveringBikes = true
        await eventEmitter.sendDiagnostic(.debug(.init(
            title: "BLE",
            detail: "discovery requested; state=\(scanner.centralStateDescription)"
        )))
        await scanner.scanForDiscovery()
    }

    public func stopBikeDiscovery() async {
        guard isDiscoveringBikes else { return }
        isDiscoveringBikes = false
        await stopScan(reason: "bike_discovery_stopped")
    }

    public func disconnect() async throws {
        guard sessionStore.shouldConnectWhenPoweredOn || sessionStore.peripheral != nil else {
            try await eventEmitter.fail(.notStarted)
            return
        }
        sessionStore.setReconnectIntent(false)
        reconnectController.reset()
        isDiscoveringBikes = false
        await stopScan(reason: "user_disconnected")
        if let peripheral = sessionStore.peripheral {
            await traceEmitter.record(
                category: "link",
                operation: .disconnectRequested,
                direction: .outbound,
                detail: "user_disconnected"
            )
            adapter.cancelConnection(peripheral)
        }
        resetSession()
        await eventEmitter.send(.connection(.disconnected(reason: BikeSDKText.disconnectedByUser)))
    }

    public func centralDidUpdateState() async {
        await eventEmitter.sendDiagnostic(.debug(.init(
            title: "BLE",
            detail: "central state \(scanner.centralStateDescription)"
        )))
        if await scanner.resumePendingRestorationIfNeeded() {
            return
        }
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
        await eventEmitter.sendDiagnostic(.debug(.init(
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
        await traceEmitter.record(
            category: "advertisement",
            operation: .advertisementReceived,
            direction: .inbound,
            detail: "target_bike rssi=\(rssi)"
        )
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
        await stopScan(reason: "target_discovered")
        await traceEmitter.record(
            category: "link",
            operation: .connectRequested,
            direction: .outbound,
            detail: "target_bike"
        )
        let peripheralIdentifier = peripheral.identifier
        connectionWatchdog.start(peripheralIdentifier: peripheralIdentifier) { [weak self] identifier in
            await self?.connectionTimedOut(peripheralIdentifier: identifier)
        }
        adapter.connect(peripheral)
    }

    public func didConnect(_ peripheral: CBPeripheral) async {
        guard sessionStore.isActive(peripheral) else { return }
        connectionWatchdog.cancel()
        let name = peripheral.name
        await eventEmitter.send(.connection(.discovering(peripheralName: name)))
        await peripheralOperations.discoverServices(BikeSDKConstants.serviceUUIDs, peripheral: peripheral)
        await peripheralOperations.readRSSI(peripheral: peripheral)
    }

    public func didFailToConnect(_ peripheral: CBPeripheral, error: Error?) async {
        guard sessionStore.isActive(peripheral) else { return }
        connectionWatchdog.cancel()
        if connectionErrorClassifier.requiresPairingReset(error) {
            await stopForPairingReset(error)
            return
        }
        let message = error?.localizedDescription ?? BikeSDKText.connectFailed
        await handleConnectionLoss(terminalStatus: .failed(message: message))
    }

    public func didDisconnect(_ peripheral: CBPeripheral, error: Error?) async {
        guard sessionStore.isActive(peripheral) else { return }
        connectionWatchdog.cancel()
        if connectionErrorClassifier.requiresPairingReset(error) {
            await stopForPairingReset(error)
            return
        }
        await handleConnectionLoss(terminalStatus: .disconnected(reason: error?.localizedDescription))
    }

}

private extension BikeBLEConnectionCoordinator {
    func scanForConnection() async throws {
        try await scanner.scanForConnection { [weak self] peripheral in
            await self?.connect(peripheral: peripheral, name: peripheral.name, rssi: nil)
        }
    }

    func reconnectIfNeeded() async {
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

    func resetSession() {
        connectionWatchdog.cancel()
        sessionResetHandler()
        sessionStore.resetSession()
    }

    func connectionTimedOut(peripheralIdentifier: UUID) async {
        guard sessionStore.peripheral?.identifier == peripheralIdentifier,
              sessionStore.shouldConnectWhenPoweredOn,
              let peripheral = sessionStore.peripheral else { return }
        await traceEmitter.record(
            category: "link",
            operation: .connectFailed,
            direction: .internalEvent,
            detail: "connection_timeout"
        )
        adapter.cancelConnection(peripheral)
        await handleConnectionLoss(terminalStatus: .failed(message: BikeSDKText.connectionTimedOut))
    }

    func maskedVIN(_ vin: String) -> String {
        guard vin.count > 4 else { return vin }
        return "...\(vin.suffix(4))"
    }

    func stopScan(reason: String) async {
        await traceEmitter.record(
            category: "central",
            operation: .scanStopped,
            direction: .outbound,
            detail: reason
        )
        adapter.stopScan()
    }
}

extension BikeBLEConnectionCoordinator {
    func handleConnectionLoss(terminalStatus: BikeSDKConnectionStatus) async {
        let shouldReconnect = sessionStore.shouldConnectWhenPoweredOn
        resetSession()
        if shouldReconnect {
            await reconnectIfNeeded()
        } else {
            await eventEmitter.send(.connection(terminalStatus))
        }
    }

    func stopForPairingReset(_ error: Error?) async {
        reconnectController.reset()
        sessionStore.setReconnectIntent(false)
        await stopScan(reason: "pairing_reset_required")
        await eventEmitter.sendDiagnostic(.debug(.init(
            title: BikeSDKText.pairingTitle,
            detail: "Pairing reset required; automatic reconnect stopped; "
                + connectionErrorClassifier.diagnosticDetail(error)
        )))
        resetSession()
        await eventEmitter.send(.connection(.pairingResetRequired(
            message: BikeSDKText.pairingResetRequired
        )))
    }
}
