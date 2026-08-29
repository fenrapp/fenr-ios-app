@testable import BikeData
import BikeDomain
import BikeSDK
import Foundation
import StarkProtocol
import Testing

@Suite("Bike IMU repository")
struct BikeIMURepositoryTests {
    @Test("Maps IMU events on their dedicated stream")
    func mapsDedicatedStream() async throws {
        let client = FakeBikeTelemetryClient()
        let repository = makeRepository(client: client)
        await repository.start()
        let stream = await repository.observeIMU()
        var iterator = stream.makeAsyncIterator()
        let date = Date(timeIntervalSince1970: 123)

        await client.send(.imu(.init(
            payload: .init(
                accelerationXRaw: 3,
                accelerationYRaw: -1_135,
                accelerationZRaw: 1_178,
                gyroscopeXRaw: 15,
                gyroscopeYRaw: -451,
                gyroscopeZRaw: 927
            ),
            observedAt: date
        )))
        let sample = try #require(await iterator.next())

        #expect(sample.accelerationRaw == .init(x: 3, y: -1_135, z: 1_178))
        #expect(sample.gyroscopeRaw == .init(x: 15, y: -451, z: 927))
        #expect(sample.observedAt == date)
    }

    @Test("Forwards optional monitoring lifecycle without starting it implicitly")
    func monitoringLifecycle() async throws {
        let client = FakeBikeTelemetryClient()
        let repository = makeRepository(client: client)
        await repository.start()

        #expect(await client.imuStartCount() == 0)
        try await repository.startIMUMonitoring()
        await repository.stopIMUMonitoring()

        #expect(await client.imuStartCount() == 1)
        #expect(await client.imuStopCount() == 1)
    }
}
