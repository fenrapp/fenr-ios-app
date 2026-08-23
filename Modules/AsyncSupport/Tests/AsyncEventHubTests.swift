import AsyncSupport
import Testing

@Suite("Async event hub")
struct AsyncEventHubTests {
    @Test("Replays an explicit value to a new subscriber")
    func replaysExplicitValue() async {
        let hub = AsyncEventHub<Int>()
        let stream = await hub.stream(replay: 42)
        var iterator = stream.makeAsyncIterator()

        #expect(await iterator.next() == 42)
    }

    @Test("Optionally replays the latest sent value")
    func replaysLatestValueWhenConfigured() async {
        let hub = AsyncEventHub<Int>(replaysLatestValue: true)
        await hub.send(7)
        let stream = await hub.stream()
        var iterator = stream.makeAsyncIterator()

        #expect(await iterator.next() == 7)
    }
}
