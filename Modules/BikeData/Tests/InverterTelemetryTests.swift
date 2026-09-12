import BikeSDK
import StarkProtocol
import Testing

@Suite("Inverter telemetry")
struct InverterTelemetryTests {
    @Test("Decoded inverter status never enters domain readings and unavailable updates replace prior sensors")
    func mapsInverterSensorUpdates() async throws {
        let client = FakeBikeTelemetryClient()
        let repository = makeRepository(client: client)
        let decoder = StarkInverterTemperaturesDecoder()
        await repository.start()
        let stream = await repository.observeTelemetry()
        var iterator = stream.makeAsyncIterator()
        _ = await iterator.next()

        let available = try decoder.decode(BikeDataTelemetryFixtures.inverterTemperaturesWithLargeStatusBytes)
        await client.send(.telemetry(.inverterTemperatures(available)))
        let telemetry = await iterator.next()

        #expect(telemetry?.inverterTemperatureRawValues == [240, 250, 260, 270, 270, 280])
        #expect(telemetry?.inverterTemperaturesCelsius == [24, 25, 26, 27, 27, 28])

        let unavailable = try decoder.decode(BikeDataTelemetryFixtures.unavailableInverterWithStatus)
        await client.send(.telemetry(.inverterTemperatures(unavailable)))
        let updated = await iterator.next()

        #expect(updated?.inverterTemperatureRawValues == [0, 0, 0, 0, 0, 0])
        #expect(updated?.inverterTemperaturesCelsius == [nil, nil, nil, nil, nil, nil])
        await repository.stop()
    }
}
