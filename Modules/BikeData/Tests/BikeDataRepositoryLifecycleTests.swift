@testable import BikeData
import BikeDomain
import BikeSDK
import Foundation
import Testing

@Suite("Bike data repository lifecycle")
struct BikeDataRepositoryLifecycleTests {
    @Test("Disconnect clears telemetry and peripheral metadata")
    func disconnectClearsSessionState() async throws {
        let client = FakeBikeTelemetryClient()
        let repository = makeRepository(client: client)
        await repository.start()
        let telemetryStream = await repository.observeTelemetry()
        let connectionStream = await repository.observeConnection()
        var telemetryIterator = telemetryStream.makeAsyncIterator()
        var connectionIterator = connectionStream.makeAsyncIterator()
        _ = await telemetryIterator.next()
        _ = await connectionIterator.next()
        await client.send(.telemetry(BikeDataTelemetryFixtures.battery))
        _ = await telemetryIterator.next()
        await client.send(.peripheral(name: "VIN", identifier: UUID()))
        _ = await connectionIterator.next()

        await client.send(.connection(.disconnected(reason: "Link lost")))
        let telemetry = try #require(await telemetryIterator.next())
        let connection = try #require(await connectionIterator.next())

        #expect(telemetry == BikeTelemetry())
        #expect(connection.state == .disconnected(reason: "Link lost"))
        #expect(connection.peripheralName == nil)
        #expect(connection.peripheralIdentifier == nil)
        #expect(connection.rssi == nil)
    }

    @Test("Stop resets replayed repository state")
    func stopResetsReplayedState() async throws {
        let client = FakeBikeTelemetryClient()
        let repository = makeRepository(client: client)
        await repository.start()
        let activeStream = await repository.observeTelemetry()
        var activeIterator = activeStream.makeAsyncIterator()
        _ = await activeIterator.next()
        await client.send(.telemetry(BikeDataTelemetryFixtures.battery))
        _ = await activeIterator.next()

        await repository.stop()
        let telemetryStream = await repository.observeTelemetry()
        let connectionStream = await repository.observeConnection()
        var telemetryIterator = telemetryStream.makeAsyncIterator()
        var connectionIterator = connectionStream.makeAsyncIterator()
        let telemetry = try #require(await telemetryIterator.next())
        let connection = try #require(await connectionIterator.next())

        #expect(telemetry == BikeTelemetry())
        #expect(connection == BikeConnection())
    }
}
