import AsyncSupport
import Testing

@Suite("Async event hub")
struct AsyncEventHubTests {
    @Test("Broadcasts values to every active subscriber")
    func broadcastsValues() async {
        let hub = AsyncEventHub<Int>(bufferingPolicy: .unbounded)
        let firstStream = await hub.stream()
        let secondStream = await hub.stream()

        await hub.send(7)

        var firstIterator = firstStream.makeAsyncIterator()
        var secondIterator = secondStream.makeAsyncIterator()
        #expect(await firstIterator.next() == 7)
        #expect(await secondIterator.next() == 7)
    }

    @Test("Does not replay values by default")
    func doesNotReplayByDefault() async {
        let hub = AsyncEventHub<Int>(bufferingPolicy: .unbounded)
        await hub.send(7)
        let stream = await hub.stream()

        await hub.send(8)

        var iterator = stream.makeAsyncIterator()
        #expect(await iterator.next() == 8)
    }

    @Test("Optionally replays the latest sent value")
    func replaysLatestValueWhenConfigured() async {
        let hub = AsyncEventHub<Int>(bufferingPolicy: .unbounded, replaysLatestValue: true)
        await hub.send(7)
        let stream = await hub.stream()
        var iterator = stream.makeAsyncIterator()

        #expect(await iterator.next() == 7)
    }

    @Test("An explicit replay takes precedence over the latest value")
    func explicitReplayTakesPrecedence() async {
        let hub = AsyncEventHub<Int>(bufferingPolicy: .unbounded, replaysLatestValue: true)
        await hub.send(7)
        let stream = await hub.stream(replay: 42)

        await hub.send(8)

        var iterator = stream.makeAsyncIterator()
        #expect(await iterator.next() == 42)
        #expect(await iterator.next() == 8)
    }

    @Test("Buffering newest drops the oldest buffered value")
    func buffersNewestValues() async {
        let hub = AsyncEventHub<Int>(bufferingPolicy: .bufferingNewest(2))
        let stream = await hub.stream()

        await hub.send(1)
        await hub.send(2)
        await hub.send(3)

        var iterator = stream.makeAsyncIterator()
        #expect(await iterator.next() == 2)
        #expect(await iterator.next() == 3)
    }

    @Test("Buffering oldest drops the newest buffered value")
    func buffersOldestValues() async {
        let hub = AsyncEventHub<Int>(bufferingPolicy: .bufferingOldest(2))
        let stream = await hub.stream()

        await hub.send(1)
        await hub.send(2)
        await hub.send(3)

        var iterator = stream.makeAsyncIterator()
        #expect(await iterator.next() == 1)
        #expect(await iterator.next() == 2)
    }

    @Test("Cancelling one subscriber does not affect another")
    func cancellationDoesNotAffectOtherSubscribers() async {
        let hub = AsyncEventHub<Int>(bufferingPolicy: .unbounded)
        let cancelledStream = await hub.stream()
        let survivingStream = await hub.stream()
        let cancelledSubscriber = Task {
            var iterator = cancelledStream.makeAsyncIterator()
            return await iterator.next()
        }

        cancelledSubscriber.cancel()
        #expect(await cancelledSubscriber.value == nil)

        await hub.send(11)
        var survivingIterator = survivingStream.makeAsyncIterator()
        #expect(await survivingIterator.next() == 11)
    }

    @Test("A new subscriber can join after another is cancelled")
    func resubscribesAfterCancellation() async {
        let hub = AsyncEventHub<Int>(bufferingPolicy: .unbounded)
        let firstStream = await hub.stream()
        let firstSubscriber = Task {
            var iterator = firstStream.makeAsyncIterator()
            return await iterator.next()
        }

        firstSubscriber.cancel()
        #expect(await firstSubscriber.value == nil)

        let replacementStream = await hub.stream()
        await hub.send(13)
        var replacementIterator = replacementStream.makeAsyncIterator()
        #expect(await replacementIterator.next() == 13)
    }

    @Test("Finish completes every active stream")
    func finishCompletesAllStreams() async {
        let hub = AsyncEventHub<Int>(bufferingPolicy: .unbounded)
        let firstStream = await hub.stream()
        let secondStream = await hub.stream()

        await hub.finish()

        var firstIterator = firstStream.makeAsyncIterator()
        var secondIterator = secondStream.makeAsyncIterator()
        #expect(await firstIterator.next() == nil)
        #expect(await secondIterator.next() == nil)
    }

    @Test("Send and stream are terminal after finish")
    func operationsAfterFinishAreTerminal() async {
        let hub = AsyncEventHub<Int>(bufferingPolicy: .unbounded, replaysLatestValue: true)
        await hub.send(7)
        await hub.finish()

        await hub.send(8)
        let stream = await hub.stream(replay: 42)
        var iterator = stream.makeAsyncIterator()

        #expect(await iterator.next() == nil)
    }

    @Test("Finish is idempotent")
    func finishIsIdempotent() async {
        let hub = AsyncEventHub<Int>(bufferingPolicy: .unbounded)
        await hub.finish()
        await hub.finish()

        let stream = await hub.stream()
        var iterator = stream.makeAsyncIterator()

        #expect(await iterator.next() == nil)
    }

    @Test("Deinitialization releases the hub and completes its streams")
    func deinitializationCompletesStreams() async {
        var hub: AsyncEventHub<Int>? = AsyncEventHub(bufferingPolicy: .unbounded)
        weak let weakHub = hub
        let stream = await hub!.stream()

        hub = nil

        #expect(weakHub == nil)
        var iterator = stream.makeAsyncIterator()
        #expect(await iterator.next() == nil)
    }
}
