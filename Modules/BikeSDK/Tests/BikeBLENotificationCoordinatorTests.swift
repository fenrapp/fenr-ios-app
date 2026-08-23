@testable import BikeSDK
import StarkProtocol
import Testing

@MainActor
@Suite("BLE notification coordinator")
struct BikeBLENotificationCoordinatorTests {
    @Test("Manual telemetry read fails clearly without an active peripheral")
    func manualReadWithoutPeripheralFails() async {
        let eventHub = AsyncEventHub<BikeSDKEvent>(bufferingPolicy: .unbounded)
        let stream = await eventHub.stream()
        let coordinator = makeNotificationCoordinator(
            sessionStore: BLESessionStore(),
            eventHub: eventHub,
            timeoutScheduler: FakeBikeBLETimeoutScheduler()
        )

        await #expect(throws: BikeSDKError.operationFailed(BikeSDKText.noActivePeripheral)) {
            try await coordinator.readTelemetrySnapshot()
        }

        var iterator = stream.makeAsyncIterator()
        await #expect(iterator.next() == .error(.operationFailed(BikeSDKText.noActivePeripheral)))
    }

    @Test("Fast status read fails clearly without an active peripheral")
    func statusReadWithoutPeripheralFails() async {
        let eventHub = AsyncEventHub<BikeSDKEvent>(bufferingPolicy: .unbounded)
        let stream = await eventHub.stream()
        let coordinator = makeNotificationCoordinator(
            sessionStore: BLESessionStore(),
            eventHub: eventHub,
            timeoutScheduler: FakeBikeBLETimeoutScheduler()
        )

        await #expect(throws: BikeSDKError.operationFailed(BikeSDKText.noActivePeripheral)) {
            try await coordinator.readBikeStatusSnapshot()
        }

        var iterator = stream.makeAsyncIterator()
        await #expect(iterator.next() == .error(.operationFailed(BikeSDKText.noActivePeripheral)))
    }
}
