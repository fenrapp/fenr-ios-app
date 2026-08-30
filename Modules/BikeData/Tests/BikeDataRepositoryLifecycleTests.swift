@testable import BikeData
import BikeDomain
import BikeSDK
import Foundation
import StarkProtocol
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

    @Test("Concurrent starts share one client startup and event stream")
    func concurrentStartsShareStartup() async {
        let client = FakeBikeTelemetryClient()
        await client.suspendStart()
        let repository = makeRepository(client: client)

        let firstStart = Task { await repository.start() }
        #expect(await client.waitUntilStartIsSuspended())
        let secondStart = Task { await repository.start() }
        #expect(await repository.lifecycleState == .starting)

        await client.resumeStart()
        await firstStart.value
        await secondStart.value

        #expect(await repository.lifecycleState == .started)
        #expect(await client.startCount() == 1)
        #expect(await client.eventStreamCount() == 1)
    }

    @Test("Stop invalidates and awaits an in-flight startup")
    func stopDuringStartupCancelsAndAwaitsStartup() async {
        let client = FakeBikeTelemetryClient()
        await client.suspendStart()
        await client.suspendStop()
        let repository = makeRepository(client: client)
        let startTask = Task { await repository.start() }
        #expect(await client.waitUntilStartIsSuspended())

        let stopTask = Task { await repository.stop() }
        #expect(await client.waitUntilStopIsSuspended())
        #expect(await repository.lifecycleState == .stopping)
        await client.resumeStart()
        await client.resumeStop()
        await startTask.value
        await stopTask.value

        #expect(await repository.lifecycleState == .stopped)
        #expect(await client.startCount() == 1)
        #expect(await client.eventStreamCount() == 0)
        #expect(await client.stopCount() == 1)
    }

    @Test("A start requested while stopping waits before opening the next session")
    func startDuringStopWaitsForShutdown() async {
        let client = FakeBikeTelemetryClient()
        let repository = makeRepository(client: client)
        await repository.start()
        await client.suspendStop()

        let stopTask = Task { await repository.stop() }
        #expect(await client.waitUntilStopIsSuspended())
        let restartTask = Task { await repository.start() }
        #expect(await repository.lifecycleState == .stopping)

        await client.resumeStop()
        await stopTask.value
        await restartTask.value

        #expect(await repository.lifecycleState == .started)
        #expect(await client.startCount() == 2)
        #expect(await client.eventStreamCount() == 2)
        #expect(await client.stopCount() == 1)
    }

    @Test("Stopping resets the IMU limiter before the next session")
    func stopResetsIMULimiter() async throws {
        let client = FakeBikeTelemetryClient()
        let repository = makeRepository(
            client: client,
            imuMinimumInterval: 1
        )
        let observedAt = Date(timeIntervalSince1970: 100)
        let sample = BikeSDKIMUSample(
            payload: .init(
                accelerationXRaw: 1,
                accelerationYRaw: 2,
                accelerationZRaw: 3,
                gyroscopeXRaw: 4,
                gyroscopeYRaw: 5,
                gyroscopeZRaw: 6
            ),
            observedAt: observedAt
        )

        await repository.start()
        let firstStream = await repository.observeIMU()
        var firstIterator = firstStream.makeAsyncIterator()
        await client.send(.imu(sample))
        #expect(try #require(await firstIterator.next()).observedAt == observedAt)

        await repository.stop()
        await repository.start()
        let secondStream = await repository.observeIMU()
        var secondIterator = secondStream.makeAsyncIterator()
        await client.send(.imu(sample))

        #expect(try #require(await secondIterator.next()).observedAt == observedAt)
    }
}
