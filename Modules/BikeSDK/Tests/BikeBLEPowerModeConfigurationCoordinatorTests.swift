@testable import BikeSDK
import Foundation
import Testing

@Suite("BLE power mode configuration coordinator")
@MainActor
struct BikeBLEPowerModeConfigurationCoordinatorTests {
    @Test("Reads all power maps before all traction maps through an authenticated session")
    func readsAllConfigurationsInOrder() async throws {
        let transport = FakeBikeBLEPowerModeConfigurationTransport()
        let coordinator = makeCoordinator(transport: transport)

        try await coordinator.refresh()

        #expect(transport.requests == expectedRequests)
        #expect(transport.allowedLiveTelemetrySessionValues == Array(repeating: false, count: 10))
    }

    @Test("Keeps a successful power refresh when every traction request fails")
    func toleratesUnavailableTractionControl() async throws {
        let transport = FakeBikeBLEPowerModeConfigurationTransport()
        transport.failingRequests = Set((0 ... 4).map { Data([0, 8, UInt8($0)]) })
        let coordinator = makeCoordinator(transport: transport)

        try await coordinator.refresh()

        #expect(transport.requests == expectedRequests)
    }

    @Test("Reads one selected power map without requesting traction")
    func readsSelectedPowerMap() async throws {
        let transport = FakeBikeBLEPowerModeConfigurationTransport()
        let coordinator = makeCoordinator(transport: transport)

        try await coordinator.refreshPowerModeConfiguration(mapIndex: 4)

        #expect(transport.requests == [Data([0, 0, 4])])
    }

    @Test("Reads one selected traction map without requesting base configuration")
    func readsSelectedTractionMap() async throws {
        let transport = FakeBikeBLEPowerModeConfigurationTransport()
        let coordinator = makeCoordinator(transport: transport)

        try await coordinator.refreshTractionControlConfiguration(mapIndex: 2)

        #expect(transport.requests == [Data([0, 8, 2])])
    }

    @Test("Normalizes a zero read curve and verifies a complete power and regen write")
    func preparesAndWritesSelectedMap() async throws {
        let transport = FakeBikeBLEPowerModeConfigurationTransport()
        let coordinator = makeCoordinator(transport: transport)

        try await coordinator.preparePowerModeControl(mapIndex: 2)
        try await coordinator.setPowerModeConfiguration(
            mapIndex: 2,
            horsepower: 50,
            regenerativeBrakingPercent: -20
        )

        #expect(transport.writePayloads == [
            Data([1, 0, 2, 1, 75, 0, 50, 0, 3]),
            Data([1, 0, 2, 1, 63, 0, 0xEC, 0xFF, 3])
        ])
        #expect(transport.requests == Array(repeating: Data([0, 0, 2]), count: 3))
    }

    @Test("Also accepts the normalized map curve in read responses")
    func acceptsNormalizedReadCurve() async throws {
        let transport = FakeBikeBLEPowerModeConfigurationTransport()
        transport.curveOverrides[2] = 3
        let coordinator = makeCoordinator(transport: transport)

        try await coordinator.preparePowerModeControl(mapIndex: 2)

        #expect(transport.writePayloads == [
            Data([1, 0, 2, 1, 75, 0, 50, 0, 3])
        ])
    }

    @Test("Prepares and verifies traction control while preserving its sibling value")
    func preparesAndWritesTractionControl() async throws {
        let transport = FakeBikeBLEPowerModeConfigurationTransport()
        let coordinator = makeCoordinator(transport: transport)

        try await coordinator.prepareTractionControl(mapIndex: 3)
        try await coordinator.setTractionControlConfiguration(
            mapIndex: 3,
            powerTractionPercent: 12,
            brakingTractionPercent: 30
        )

        #expect(transport.writePayloads == [
            Data([1, 8, 1, 3, 15, 0xC8, 0, 0xC8, 0]),
            Data([1, 8, 1, 3, 15, 0x78, 0, 0x2C, 0x01])
        ])
        #expect(transport.requests == Array(repeating: Data([0, 8, 3]), count: 3))
    }

    @Test("Requires traction-control compatible firmware before its no-op write")
    func rejectsUnsupportedTractionControlFirmware() async {
        let transport = FakeBikeBLEPowerModeConfigurationTransport()
        transport.versionData = Data("1.10.0".utf8)
        let coordinator = makeCoordinator(transport: transport)

        await #expect(throws: BikeSDKError.self) {
            try await coordinator.prepareTractionControl(mapIndex: 0)
        }
        #expect(transport.writePayloads.isEmpty)
    }

    @Test("Invalidates base and traction guards after write transport failures")
    func invalidatesGuardsAfterWriteFailures() async throws {
        let baseTransport = FakeBikeBLEPowerModeConfigurationTransport()
        let baseCoordinator = makeCoordinator(transport: baseTransport)
        try await baseCoordinator.preparePowerModeControl(mapIndex: 0)
        baseTransport.writeError = BikeSDKError.operationFailed("Synthetic write failure")

        await #expect(throws: BikeSDKError.self) {
            try await baseCoordinator.setPowerModeConfiguration(
                mapIndex: 0,
                horsepower: 50,
                regenerativeBrakingPercent: 30
            )
        }
        baseTransport.writeError = nil
        await #expect(throws: BikeSDKError.self) {
            try await baseCoordinator.setPowerModeConfiguration(
                mapIndex: 0,
                horsepower: 50,
                regenerativeBrakingPercent: 30
            )
        }

        let tractionTransport = FakeBikeBLEPowerModeConfigurationTransport()
        let tractionCoordinator = makeCoordinator(transport: tractionTransport)
        try await tractionCoordinator.prepareTractionControl(mapIndex: 0)
        tractionTransport.writeError = BikeSDKError.operationFailed("Synthetic write failure")

        await #expect(throws: BikeSDKError.self) {
            try await tractionCoordinator.setTractionControlConfiguration(
                mapIndex: 0,
                powerTractionPercent: 20,
                brakingTractionPercent: 30
            )
        }
        tractionTransport.writeError = nil
        await #expect(throws: BikeSDKError.self) {
            try await tractionCoordinator.setTractionControlConfiguration(
                mapIndex: 0,
                powerTractionPercent: 20,
                brakingTractionPercent: 30
            )
        }
    }

    @Test("Rejects an unexpected map curve before enabling writes")
    func rejectsUnexpectedCurve() async {
        let transport = FakeBikeBLEPowerModeConfigurationTransport()
        let coordinator = makeCoordinator(transport: transport)
        transport.curveOverrides[4] = 9

        await #expect(throws: BikeSDKError.self) {
            try await coordinator.preparePowerModeControl(mapIndex: 4)
        }
    }

    @Test("Fails verification when no power configuration is received")
    func requiresAtLeastOnePowerConfiguration() async {
        let transport = FakeBikeBLEPowerModeConfigurationTransport()
        transport.failingRequests = Set((0 ... 4).map { Data([0, 0, UInt8($0)]) })
        let coordinator = makeCoordinator(transport: transport)

        await #expect(throws: BikeSDKError.self) {
            try await coordinator.refresh()
        }
        #expect(transport.requests == Array(expectedRequests.prefix(5)))
    }

    @Test("Publishes each decoded map to the diagnostics event stream")
    func publishesMapDiagnostics() async throws {
        let transport = FakeBikeBLEPowerModeConfigurationTransport()
        let eventHub = AsyncEventHub<BikeSDKEvent>(bufferingPolicy: .unbounded)
        let stream = await eventHub.stream()
        var iterator = stream.makeAsyncIterator()
        let coordinator = makeCoordinator(transport: transport, eventHub: eventHub)

        try await coordinator.refresh()

        var details: [String] = []
        for _ in 0 ..< 20 {
            let event = try #require(await iterator.next())
            if case .debug(let debug) = event {
                details.append(debug.detail)
            }
        }
        #expect(details.count == 10)
        #expect(details.contains { $0.contains("power map 4 decoded") })
        #expect(details.contains { $0.contains("TC map 4 decoded") })
    }

    private var expectedRequests: [Data] {
        (0 ... 4).map { Data([0, 0, UInt8($0)]) }
            + (0 ... 4).map { Data([0, 8, UInt8($0)]) }
    }

    private func makeCoordinator(
        transport: FakeBikeBLEPowerModeConfigurationTransport,
        eventHub: AsyncEventHub<BikeSDKEvent> = .init(bufferingPolicy: .unbounded)
    ) -> BikeBLEPowerModeConfigurationCoordinator {
        BikeBLEPowerModeConfigurationCoordinator(
            transport: transport,
            eventEmitter: makeEventEmitter(eventHub: eventHub)
        )
    }
}
