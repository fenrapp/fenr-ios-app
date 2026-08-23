import Testing
import TestSupport

@MainActor
@Suite("Async test support")
struct AsyncTestSupportTests {
    @Test("Waits until an asynchronous condition succeeds")
    func waitsUntilConditionSucceeds() async {
        let counter = AsyncTestCounter()

        let didComplete = await waitUntil(timeout: .milliseconds(100)) {
            await counter.increment() >= 2
        }

        #expect(didComplete)
    }

    @Test("Reports when a condition does not settle")
    func reportsUnsettledCondition() async {
        #expect(!(await waitUntil(timeout: .milliseconds(1)) { false }))
    }

    @Test("Replays the latest test event to a new subscriber")
    func replaysEvent() async {
        let hub = TestEventHub<Int>()
        let stream = await hub.stream(replay: 42)
        var iterator = stream.makeAsyncIterator()
        let value = await iterator.next()

        #expect(value == 42)
    }

    @Test("Waits for an event subscriber without polling")
    func waitsForSubscriber() async {
        let hub = TestEventHub<Int>()
        let waitingTask = Task {
            await hub.waitForSubscriber()
            return true
        }

        await Task.yield()
        _ = await hub.stream()

        #expect(await waitingTask.value)
    }
}

private actor AsyncTestCounter {
    private var value = 0

    func increment() -> Int {
        value += 1
        return value
    }
}
