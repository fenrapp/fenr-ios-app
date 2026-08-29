@testable import BikeSDK
import Foundation
import Testing

@Suite("BLE Bike Lock configuration coordinator")
@MainActor
struct BikeBLEBikeLockConfigurationCoordinatorTests {
    @Test("Requires compatible VCU firmware before writing")
    func rejectsUnsupportedFirmware() async {
        let transport = FakeBikeBLEBikeLockConfigurationTransport()
        transport.versionData = Data("1.6.28".utf8)
        let coordinator = makeCoordinator(transport: transport)

        await #expect(throws: BikeSDKError.self) {
            try await coordinator.prepare()
        }
        #expect(transport.writePayloads.isEmpty)
    }

    @Test("Performs an exact no-op and confirms it with a fresh read")
    func preparesWithConfirmedNoOp() async throws {
        let transport = FakeBikeBLEBikeLockConfigurationTransport()
        transport.configuration = .init(isLocked: true, lockType: 1, timeoutSeconds: 0)
        let coordinator = makeCoordinator(transport: transport)

        let snapshot = try await coordinator.prepare()

        #expect(snapshot.isLocked)
        #expect(snapshot.didPassNoOpWrite)
        #expect(transport.requests == [Data([0, 5]), Data([0, 5])])
        #expect(transport.writePayloads == [Data([1, 5, 0x83, 1, 1, 0, 0])])
    }

    @Test("Writes the flag only after preparation and confirms the new state")
    func writesAndConfirmsLockFlag() async throws {
        let transport = FakeBikeBLEBikeLockConfigurationTransport()
        let coordinator = makeCoordinator(transport: transport)

        _ = try await coordinator.prepare()
        let snapshot = try await coordinator.setLocked(true)

        #expect(snapshot.isLocked)
        #expect(transport.writePayloads.last == Data([1, 5, 0x83, 1, 1, 0, 0]))
        #expect(transport.requests.count == 3)
    }

    @Test("Fails when the VCU fresh read does not confirm the write")
    func rejectsUnconfirmedWrite() async throws {
        let transport = FakeBikeBLEBikeLockConfigurationTransport()
        let coordinator = makeCoordinator(transport: transport)
        _ = try await coordinator.prepare()
        transport.ignoresWrites = true

        await #expect(throws: BikeSDKError.self) {
            try await coordinator.setLocked(true)
        }
    }

    private func makeCoordinator(
        transport: FakeBikeBLEBikeLockConfigurationTransport
    ) -> BikeBLEBikeLockConfigurationCoordinator {
        BikeBLEBikeLockConfigurationCoordinator(
            transport: transport,
            eventEmitter: makeEventEmitter(
                eventHub: .init(bufferingPolicy: .unbounded)
            )
        )
    }
}
