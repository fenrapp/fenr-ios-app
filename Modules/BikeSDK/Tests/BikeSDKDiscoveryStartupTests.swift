@testable import BikeSDK
import CoreBluetooth
import Testing

@Suite("Bike SDK discovery startup")
struct BikeSDKDiscoveryStartupTests {
    @MainActor
    @Test("Discovery waits for CoreBluetooth to resolve its initial state")
    func waitsForInitialBluetoothState() async {
        let adapter = FakeCoreBluetoothAdapter()
        adapter.state = .unknown
        let hub = AsyncEventHub<BikeSDKEvent>(bufferingPolicy: .unbounded)
        let stream = await hub.stream()
        var iterator = stream.makeAsyncIterator()
        let coordinator = makeConnectionCoordinator(adapter: adapter, eventHub: hub)

        await coordinator.startBikeDiscovery()

        #expect(adapter.scanCount == 0)

        adapter.state = .poweredOn
        await coordinator.centralDidUpdateState()

        #expect(adapter.scanCount == 1)

        await coordinator.stopBikeDiscovery()
        await coordinator.centralDidUpdateState()

        await #expect(nextNonDebugEvent(&iterator) == .connection(.idle))
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
