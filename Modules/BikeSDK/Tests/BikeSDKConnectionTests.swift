@testable import BikeSDK
import CoreBluetooth
import Foundation
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
        await #expect(nextNonDebugEvent(&iterator) == .error(.emptyVIN))
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

        await #expect(nextNonDebugEvent(&iterator) == .connection(.scanning(vin: "VIN123")))
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

        await #expect(nextNonDebugEvent(&iterator) == .connection(.bluetoothPoweredOff))
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

        await #expect(nextNonDebugEvent(&iterator) == .connection(.scanning(vin: "VIN123")))
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
        await #expect(nextNonDebugEvent(&iterator) == .connection(.bluetoothPoweredOff))

        adapter.state = .poweredOn
        await coordinator.centralDidUpdateState()

        await #expect(nextNonDebugEvent(&iterator) == .connection(.scanning(vin: "VIN123")))
        #expect(adapter.scanCount == 1)
    }

    @MainActor
    @Test("Bike discovery starts after Bluetooth becomes available")
    func discoveryStartsAfterBluetoothBecomesAvailable() async {
        let adapter = FakeCoreBluetoothAdapter()
        adapter.state = .poweredOff
        let hub = AsyncEventHub<BikeSDKEvent>(bufferingPolicy: .unbounded)
        let stream = await hub.stream()
        var iterator = stream.makeAsyncIterator()
        let coordinator = makeConnectionCoordinator(adapter: adapter, eventHub: hub)

        await coordinator.startBikeDiscovery()
        await #expect(nextNonDebugEvent(&iterator) == .connection(.bluetoothPoweredOff))
        #expect(adapter.scanCount == 0)

        adapter.state = .poweredOn
        await coordinator.centralDidUpdateState()

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

        await #expect(nextNonDebugEvent(&iterator) == .error(.bluetoothUnavailable))
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
        _ = await nextNonDebugEvent(&iterator)

        await #expect(
            throws: BikeSDKError.operationFailed(BikeSDKText.connectionAlreadyActive)
        ) {
            try await coordinator.connect(to: "VIN123")
        }

        await #expect(
            nextNonDebugEvent(&iterator)
                == .error(.operationFailed(BikeSDKText.connectionAlreadyActive))
        )
        #expect(adapter.scanCount == 1)
    }

    @MainActor
    @Test("Pairing reset stops automatic reconnect and reports actionable guidance")
    func pairingResetStopsReconnect() async throws {
        let adapter = FakeCoreBluetoothAdapter()
        adapter.state = .poweredOn
        let hub = AsyncEventHub<BikeSDKEvent>(bufferingPolicy: .unbounded)
        let stream = await hub.stream()
        var iterator = stream.makeAsyncIterator()
        var sessionResetCount = 0
        let coordinator = makeConnectionCoordinator(
            adapter: adapter,
            eventHub: hub,
            sessionResetHandler: { sessionResetCount += 1 }
        )
        try await coordinator.connect(to: "VIN123")
        _ = await nextNonDebugEvent(&iterator)

        let error = NSError(
            domain: CBErrorDomain,
            code: CBError.peerRemovedPairingInformation.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "Peer removed pairing information"]
        )
        await coordinator.stopForPairingReset(error)

        await #expect(
            nextNonDebugEvent(&iterator)
                == .connection(.pairingResetRequired(message: BikeSDKText.pairingResetRequired))
        )
        #expect(sessionResetCount == 1)

        await coordinator.centralDidUpdateState()

        await #expect(nextNonDebugEvent(&iterator) == .connection(.idle))
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
        var sessionResetCount = 0
        let coordinator = makeConnectionCoordinator(
            adapter: adapter,
            eventHub: hub,
            sessionResetHandler: { sessionResetCount += 1 }
        )
        try await coordinator.connect(to: "VIN123")
        _ = await nextNonDebugEvent(&iterator)

        try await coordinator.disconnect()

        await #expect(
            nextNonDebugEvent(&iterator)
                == .connection(.disconnected(reason: BikeSDKText.disconnectedByUser))
        )
        #expect(adapter.stopScanCount == 2)
        #expect(sessionResetCount == 1)
    }

    @MainActor
    @Test("Stopping the coordinator disables future Bluetooth recovery scans")
    func stopDisablesRecoveryScans() async throws {
        let adapter = FakeCoreBluetoothAdapter()
        adapter.state = .poweredOff
        let hub = AsyncEventHub<BikeSDKEvent>(bufferingPolicy: .unbounded)
        var sessionResetCount = 0
        let coordinator = makeConnectionCoordinator(
            adapter: adapter,
            eventHub: hub,
            sessionResetHandler: { sessionResetCount += 1 }
        )

        try await coordinator.connect(to: "VIN123")
        await coordinator.stop()
        adapter.state = .poweredOn
        await coordinator.centralDidUpdateState()

        #expect(adapter.scanCount == 0)
        #expect(sessionResetCount == 1)
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

        await #expect(nextNonDebugEvent(&iterator) == .connection(.idle))
        #expect(adapter.stopScanCount == 1)
        #expect(adapter.scanCount == 0)
    }
}

private func nextNonDebugEvent(
    _ iterator: inout AsyncStream<BikeSDKEvent>.Iterator
) async -> BikeSDKEvent? {
    while let event = await iterator.next() {
        guard case .debug = event else { return event }
    }
    return nil
}
