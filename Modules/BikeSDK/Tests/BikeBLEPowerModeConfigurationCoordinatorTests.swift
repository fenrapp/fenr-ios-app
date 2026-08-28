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
