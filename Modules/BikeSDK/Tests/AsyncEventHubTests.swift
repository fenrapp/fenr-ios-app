@testable import BikeSDK
import Testing

@Suite("Bike SDK event buffering")
struct AsyncEventHubTests {
    @Test("A bounded stream retains only its newest events")
    func retainsNewestEvents() async {
        let eventHub = AsyncEventHub<Int>(bufferingPolicy: .bufferingNewest(2))
        let stream = await eventHub.stream()
        await eventHub.send(1)
        await eventHub.send(2)
        await eventHub.send(3)

        var iterator = stream.makeAsyncIterator()
        let firstValue = await iterator.next()
        let secondValue = await iterator.next()

        #expect(firstValue == 2)
        #expect(secondValue == 3)
    }
}
