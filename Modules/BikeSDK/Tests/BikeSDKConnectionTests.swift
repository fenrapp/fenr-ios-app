@testable import BikeSDK
import RuntimeConfiguration
import Testing

@Suite("Bike SDK connection")
struct BikeSDKConnectionTests {
    @MainActor
    @Test("Connection coordinator rejects empty VIN and emits error")
    func emptyVINFails() async {
        let adapter = FakeCoreBluetoothAdapter()
        let hub = AsyncEventHub<BikeSDKEvent>(bufferingPolicy: .unbounded)
        let stream = await hub.stream()
        var iterator = stream.makeAsyncIterator()
        let coordinator = makeConnectionCoordinator(adapter: adapter, eventHub: hub)

        await #expect(throws: BikeSDKError.emptyVIN) {
            try await coordinator.connect(to: " ")
        }
        await #expect(iterator.next() == .error(.emptyVIN))
    }

    @MainActor
    @Test("Connection coordinator checks connected peripherals before scanning")
    func poweredOnScans() async throws {
        let adapter = FakeCoreBluetoothAdapter()
        adapter.state = .poweredOn
        let hub = AsyncEventHub<BikeSDKEvent>(bufferingPolicy: .unbounded)
        let stream = await hub.stream()
        var iterator = stream.makeAsyncIterator()
        let coordinator = makeConnectionCoordinator(adapter: adapter, eventHub: hub)

        try await coordinator.connect(to: "VIN123")

        await #expect(iterator.next() == .connection(.scanning(vin: "VIN123")))
        #expect(adapter.stopScanCount == 1)
        #expect(adapter.retrieveConnectedPeripheralsCount == 1)
        #expect(adapter.scanCount == 1)
    }

    @MainActor
    @Test("Connection coordinator reports powered off without scanning")
    func poweredOffDoesNotScan() async throws {
        let adapter = FakeCoreBluetoothAdapter()
        adapter.state = .poweredOff
        let hub = AsyncEventHub<BikeSDKEvent>(bufferingPolicy: .unbounded)
        let stream = await hub.stream()
        var iterator = stream.makeAsyncIterator()
        let coordinator = makeConnectionCoordinator(adapter: adapter, eventHub: hub)

        try await coordinator.connect(to: "VIN123")

        await #expect(iterator.next() == .connection(.bluetoothPoweredOff))
        #expect(adapter.scanCount == 0)
    }

    @MainActor
    @Test("Connection coordinator trims the VIN before scanning")
    func connectionTrimsVIN() async throws {
        let adapter = FakeCoreBluetoothAdapter()
        adapter.state = .poweredOn
        let hub = AsyncEventHub<BikeSDKEvent>(bufferingPolicy: .unbounded)
        let stream = await hub.stream()
        var iterator = stream.makeAsyncIterator()
        let coordinator = makeConnectionCoordinator(adapter: adapter, eventHub: hub)

        try await coordinator.connect(to: "  VIN123  ")

        await #expect(iterator.next() == .connection(.scanning(vin: "VIN123")))
    }

    @MainActor
    @Test("Connection coordinator recovers when Bluetooth becomes available")
    func connectionRecoversAfterBluetoothBecomesAvailable() async throws {
        let adapter = FakeCoreBluetoothAdapter()
        adapter.state = .poweredOff
        let hub = AsyncEventHub<BikeSDKEvent>(bufferingPolicy: .unbounded)
        let stream = await hub.stream()
        var iterator = stream.makeAsyncIterator()
        let coordinator = makeConnectionCoordinator(adapter: adapter, eventHub: hub)

        try await coordinator.connect(to: "VIN123")
        await #expect(iterator.next() == .connection(.bluetoothPoweredOff))

        adapter.state = .poweredOn
        await coordinator.centralDidUpdateState()

        await #expect(iterator.next() == .connection(.scanning(vin: "VIN123")))
        #expect(adapter.scanCount == 1)
    }

    @MainActor
    @Test("Connection coordinator reports unavailable Bluetooth as an error")
    func unavailableBluetoothFails() async {
        let adapter = FakeCoreBluetoothAdapter()
        adapter.state = .unknown
        let hub = AsyncEventHub<BikeSDKEvent>(bufferingPolicy: .unbounded)
        let stream = await hub.stream()
        var iterator = stream.makeAsyncIterator()
        let coordinator = makeConnectionCoordinator(adapter: adapter, eventHub: hub)

        await #expect(throws: BikeSDKError.bluetoothUnavailable) {
            try await coordinator.connect(to: "VIN123")
        }

        await #expect(iterator.next() == .error(.bluetoothUnavailable))
        #expect(adapter.scanCount == 0)
    }

    @MainActor
    @Test("Connection coordinator rejects a duplicate connection intent while scanning")
    func duplicateConnectionIntentFails() async throws {
        let adapter = FakeCoreBluetoothAdapter()
        adapter.state = .poweredOn
        let hub = AsyncEventHub<BikeSDKEvent>(bufferingPolicy: .unbounded)
        let stream = await hub.stream()
        var iterator = stream.makeAsyncIterator()
        let coordinator = makeConnectionCoordinator(adapter: adapter, eventHub: hub)
        try await coordinator.connect(to: "VIN123")
        _ = await iterator.next()

        await #expect(
            throws: BikeSDKError.operationFailed(BikeSDKText.connectionAlreadyActive)
        ) {
            try await coordinator.connect(to: "VIN123")
        }

        await #expect(
            iterator.next()
                == .error(.operationFailed(BikeSDKText.connectionAlreadyActive))
        )
        #expect(adapter.scanCount == 1)
    }

    @MainActor
    @Test("Disconnect cancels an active scan before a peripheral is discovered")
    func disconnectCancelsPendingScan() async throws {
        let adapter = FakeCoreBluetoothAdapter()
        adapter.state = .poweredOn
        let hub = AsyncEventHub<BikeSDKEvent>(bufferingPolicy: .unbounded)
        let stream = await hub.stream()
        var iterator = stream.makeAsyncIterator()
        let coordinator = makeConnectionCoordinator(adapter: adapter, eventHub: hub)
        try await coordinator.connect(to: "VIN123")
        _ = await iterator.next()

        try await coordinator.disconnect()

        await #expect(
            iterator.next()
                == .connection(.disconnected(reason: BikeSDKText.disconnectedByUser))
        )
        #expect(adapter.stopScanCount == 2)
    }

    @MainActor
    @Test("Stopping the coordinator disables future Bluetooth recovery scans")
    func stopDisablesRecoveryScans() async throws {
        let adapter = FakeCoreBluetoothAdapter()
        adapter.state = .poweredOff
        let hub = AsyncEventHub<BikeSDKEvent>(bufferingPolicy: .unbounded)
        let coordinator = makeConnectionCoordinator(adapter: adapter, eventHub: hub)

        try await coordinator.connect(to: "VIN123")
        await coordinator.stop()
        adapter.state = .poweredOn
        await coordinator.centralDidUpdateState()

        #expect(adapter.scanCount == 0)
    }

    @MainActor
    @Test("CoreBluetooth client start initializes adapter only once")
    func clientStartIsIdempotent() async {
        let adapter = FakeCoreBluetoothAdapter()
        let hub = AsyncEventHub<BikeSDKEvent>(bufferingPolicy: .unbounded)
        let client = makeTelemetryClient(adapter: adapter, eventHub: hub)

        await client.start()
        await client.start()

        #expect(adapter.startCount == 1)
        #expect(adapter.restorationIdentifier == FENRRuntimeConstants.BikeSDK.centralRestorationIdentifier)
    }

    @MainActor
    @Test("Client connect starts the CoreBluetooth runtime when needed")
    func clientConnectStartsRuntime() async throws {
        let adapter = FakeCoreBluetoothAdapter()
        adapter.state = .poweredOn
        let hub = AsyncEventHub<BikeSDKEvent>(bufferingPolicy: .unbounded)
        let client = makeTelemetryClient(adapter: adapter, eventHub: hub)

        try await client.connect(to: "VIN123")

        #expect(adapter.startCount == 1)
        #expect(adapter.scanCount == 1)
    }

    @MainActor
    @Test("CoreBluetooth client stop clears state without scanning")
    func clientStopDoesNotScan() async {
        let adapter = FakeCoreBluetoothAdapter()
        let hub = AsyncEventHub<BikeSDKEvent>(bufferingPolicy: .unbounded)
        let stream = await hub.stream()
        var iterator = stream.makeAsyncIterator()
        let client = makeTelemetryClient(adapter: adapter, eventHub: hub)

        await client.stop()

        await #expect(iterator.next() == .connection(.idle))
        #expect(adapter.stopScanCount == 1)
        #expect(adapter.scanCount == 0)
    }
}
