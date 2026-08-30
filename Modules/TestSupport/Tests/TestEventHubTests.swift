import Testing
@testable import TestSupport

@Suite("Test event hub")
struct TestEventHubTests {
    @Test("Broadcasts events to every subscriber")
    func broadcastsEvents() async {
        let hub = TestEventHub<Int>(bufferingPolicy: .unbounded)
        let firstStream = await hub.stream()
        let secondStream = await hub.stream()

        await hub.send(7)

        var firstIterator = firstStream.makeAsyncIterator()
        var secondIterator = secondStream.makeAsyncIterator()
        #expect(await firstIterator.next() == 7)
        #expect(await secondIterator.next() == 7)
    }

    @Test("Replays an explicit event to a new subscriber")
    func replaysExplicitEvent() async {
        let hub = TestEventHub<Int>(bufferingPolicy: .unbounded)
        let stream = await hub.stream(replay: 42)
        var iterator = stream.makeAsyncIterator()

        #expect(await iterator.next() == 42)
    }

    @Test("Does not replay a previously sent event")
    func doesNotReplaySentEvents() async {
        let hub = TestEventHub<Int>(bufferingPolicy: .unbounded)
        await hub.send(7)
        let stream = await hub.stream()

        await hub.send(8)

        var iterator = stream.makeAsyncIterator()
        #expect(await iterator.next() == 8)
    }

    @Test("Buffering newest drops the oldest buffered event")
    func buffersNewestEvents() async {
        let hub = TestEventHub<Int>(bufferingPolicy: .bufferingNewest(2))
        let stream = await hub.stream()

        await hub.send(1)
        await hub.send(2)
        await hub.send(3)

        var iterator = stream.makeAsyncIterator()
        #expect(await iterator.next() == 2)
        #expect(await iterator.next() == 3)
    }

    @Test("Buffering oldest drops the newest buffered event")
    func buffersOldestEvents() async {
        let hub = TestEventHub<Int>(bufferingPolicy: .bufferingOldest(2))
        let stream = await hub.stream()

        await hub.send(1)
        await hub.send(2)
        await hub.send(3)

        var iterator = stream.makeAsyncIterator()
        #expect(await iterator.next() == 1)
        #expect(await iterator.next() == 2)
    }

    @Test("Reports an existing subscriber immediately")
    func reportsExistingSubscriber() async {
        let sleepRecorder = SleepCallRecorder<Duration>()
        let hub = TestEventHub<Int>(bufferingPolicy: .unbounded) { duration in
            await sleepRecorder.record(duration)
        }
        _ = await hub.stream()

        #expect(await hub.waitForSubscriber(timeout: .seconds(5)))
        let recordedSleeps = await sleepRecorder.recordedValues()
        #expect(recordedSleeps.isEmpty)
    }

    @Test("Waits for a later subscriber")
    func waitsForLaterSubscriber() async {
        let sleepRecorder = SleepCallRecorder<Duration>()
        let hub = TestEventHub<Int>(bufferingPolicy: .unbounded) { duration in
            await sleepRecorder.record(duration)
            try await Task.sleep(for: .seconds(60))
        }
        let waitingTask = Task {
            await hub.waitForSubscriber(timeout: .seconds(5))
        }

        await sleepRecorder.waitForCall()
        _ = await hub.stream()

        #expect(await waitingTask.value)
    }

    @Test("A subscriber resolves every registered waiter")
    func subscriberResolvesAllWaiters() async {
        let sleepRecorder = SleepCallRecorder<Duration>()
        let hub = TestEventHub<Int>(bufferingPolicy: .unbounded) { duration in
            await sleepRecorder.record(duration)
            try await Task.sleep(for: .seconds(60))
        }
        let firstWaitingTask = Task {
            await hub.waitForSubscriber(timeout: .seconds(5))
        }
        let secondWaitingTask = Task {
            await hub.waitForSubscriber(timeout: .seconds(5))
        }

        await sleepRecorder.waitForCall(count: 2)
        _ = await hub.stream()

        #expect(await firstWaitingTask.value)
        #expect(await secondWaitingTask.value)
    }

    @Test("Times out while waiting for a subscriber")
    func subscriberWaitTimesOut() async {
        let sleepRecorder = SleepCallRecorder<Duration>()
        let hub = TestEventHub<Int>(bufferingPolicy: .unbounded) { duration in
            await sleepRecorder.record(duration)
        }

        #expect(!(await hub.waitForSubscriber(timeout: .seconds(3))))
        #expect(await sleepRecorder.recordedValues() == [.seconds(3)])

        _ = await hub.stream()
    }

    @Test("A nonpositive timeout fails without sleeping")
    func nonpositiveSubscriberTimeoutFailsImmediately() async {
        let sleepRecorder = SleepCallRecorder<Duration>()
        let hub = TestEventHub<Int>(bufferingPolicy: .unbounded) { duration in
            await sleepRecorder.record(duration)
        }

        #expect(!(await hub.waitForSubscriber(timeout: .zero)))
        let recordedSleeps = await sleepRecorder.recordedValues()
        #expect(recordedSleeps.isEmpty)
    }

    @Test("Cancellation resolves false and does not affect a later subscriber")
    func subscriberWaitCancellationReturnsFalse() async {
        let sleepRecorder = SleepCallRecorder<Duration>()
        let hub = TestEventHub<Int>(bufferingPolicy: .unbounded) { duration in
            await sleepRecorder.record(duration)
            try await Task.sleep(for: .seconds(60))
        }
        let waitingTask = Task {
            await hub.waitForSubscriber(timeout: .seconds(5))
        }

        await sleepRecorder.waitForCall()
        waitingTask.cancel()
        #expect(!(await waitingTask.value))

        let stream = await hub.stream()
        await hub.send(11)
        var iterator = stream.makeAsyncIterator()
        #expect(await iterator.next() == 11)
    }

    @Test("Cancelling one event subscriber leaves another active")
    func eventSubscriberCancellationIsIsolated() async {
        let hub = TestEventHub<Int>(bufferingPolicy: .unbounded)
        let cancelledStream = await hub.stream()
        let survivingStream = await hub.stream()
        let cancelledTask = Task {
            var iterator = cancelledStream.makeAsyncIterator()
            return await iterator.next()
        }

        cancelledTask.cancel()
        #expect(await cancelledTask.value == nil)

        await hub.send(13)
        var survivingIterator = survivingStream.makeAsyncIterator()
        #expect(await survivingIterator.next() == 13)
    }

    @Test("Finish completes every stream and waiting subscriber request")
    func finishCompletesStreamsAndWaiters() async {
        let sleepRecorder = SleepCallRecorder<Duration>()
        let hub = TestEventHub<Int>(bufferingPolicy: .unbounded) { duration in
            await sleepRecorder.record(duration)
            try await Task.sleep(for: .seconds(60))
        }
        let stream = await hub.stream()
        let waitingHub = TestEventHub<Int>(bufferingPolicy: .unbounded) { duration in
            await sleepRecorder.record(duration)
            try await Task.sleep(for: .seconds(60))
        }
        let waitingTask = Task {
            await waitingHub.waitForSubscriber(timeout: .seconds(5))
        }

        await sleepRecorder.waitForCall(count: 1)
        await hub.finish()
        await waitingHub.finish()

        var iterator = stream.makeAsyncIterator()
        #expect(await iterator.next() == nil)
        #expect(!(await waitingTask.value))
    }

    @Test("Operations remain terminal after finish")
    func operationsAfterFinishAreTerminal() async {
        let hub = TestEventHub<Int>(bufferingPolicy: .unbounded)
        await hub.finish()
        await hub.send(7)

        let stream = await hub.stream(replay: 42)
        var iterator = stream.makeAsyncIterator()

        #expect(await iterator.next() == nil)
        #expect(!(await hub.waitForSubscriber()))
    }

    @Test("Finish is idempotent")
    func finishIsIdempotent() async {
        let hub = TestEventHub<Int>(bufferingPolicy: .unbounded)
        await hub.finish()
        await hub.finish()

        let stream = await hub.stream()
        var iterator = stream.makeAsyncIterator()
        #expect(await iterator.next() == nil)
    }

    @Test("Deinitialization releases the hub and completes its streams")
    func deinitializationCompletesStreams() async {
        var hub: TestEventHub<Int>? = TestEventHub(bufferingPolicy: .unbounded)
        weak let weakHub = hub
        let stream = await hub!.stream()

        hub = nil

        #expect(weakHub == nil)
        var iterator = stream.makeAsyncIterator()
        #expect(await iterator.next() == nil)
    }
}
