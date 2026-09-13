import BikeDomain
import BikeSDK
import Foundation
import StarkProtocol
import Testing

@Suite("Experimental bike usage counter")
struct BikeUsageCounterTests {
    @Test("Preserves the fourth counter and its sample time, then clears it on session reset")
    func receivesCounterAndResets() async throws {
        let client = FakeBikeTelemetryClient()
        let repository = makeRepository(client: client)
        await repository.start()
        var iterator = await repository.observeTelemetry().makeAsyncIterator()
        #expect(await iterator.next()?.experimentalUsageCounter == nil)
        let decoder = StarkLiveTotalsDecoder()
        let payload = try decoder.decode(Data([
            0x10, 0x27, 0, 0, 0x20, 0x4e, 0, 0,
            0x30, 0x75, 0, 0, 0xff, 0xff, 0xff, 0xff
        ]))
        await client.send(.telemetry(.liveTotals(payload)))
        let updated = await iterator.next()
        #expect(updated?.experimentalUsageCounter?.rawValue == UInt32.max)
        #expect(updated?.experimentalUsageCounter?.sampledAt == updated?.lastUpdated)
        #expect(updated?.odometer.kilometers == 100)
        await client.send(.telemetry(.liveTotals(.init(
            firstRawCounter: 10_000, secondRawCounter: 20_000,
            thirdRawCounter: 30_000, fourthRawCounter: 0
        ))))
        #expect(await iterator.next()?.experimentalUsageCounter?.rawValue == 0)
        await repository.stop()
        var stopped = await repository.observeTelemetry().makeAsyncIterator()
        #expect(await stopped.next()?.experimentalUsageCounter == nil)
    }
}
