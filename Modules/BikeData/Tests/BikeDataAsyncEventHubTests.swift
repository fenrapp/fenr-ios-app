@testable import BikeData
import Testing

@Suite("Bike data event buffering")
struct BikeDataAsyncEventHubTests {
    @Test("A bounded stream retains only its newest events")
    func retainsNewestEvents() async {
        let eventHub = AsyncEventHub<Int>(bufferingPolicy: .bufferingNewest(1))
        let stream = await eventHub.stream()
        await eventHub.send(1)
        await eventHub.send(2)

        var iterator = stream.makeAsyncIterator()
        let value = await iterator.next()

        #expect(value == 2)
    }
}
