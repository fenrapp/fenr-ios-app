import Testing
@testable import TestSupport

@MainActor
@Suite("Async test waiter")
struct AsyncTestWaiterTests {
    @Test("Returns true on the first successful evaluation")
    func succeedsImmediately() async {
        let clock = ManualTestClock()
        var evaluationCount = 0

        let didComplete = await waitUntil(
            timeout: .seconds(1),
            pollingInterval: .milliseconds(10),
            clock: clock,
            sleepUntil: { deadline in clock.recordSleepAndAdvance(to: deadline) },
            condition: {
                evaluationCount += 1
                return true
            }
        )

        #expect(didComplete)
        #expect(evaluationCount == 1)
        #expect(clock.recordedSleepDeadlines().isEmpty)
    }

    @Test("Polls again after sleeping")
    func pollsAfterSleeping() async {
        let clock = ManualTestClock()
        var evaluationCount = 0

        let didComplete = await waitUntil(
            timeout: .seconds(1),
            pollingInterval: .milliseconds(10),
            clock: clock,
            sleepUntil: { deadline in clock.recordSleepAndAdvance(to: deadline) },
            condition: {
                evaluationCount += 1
                return evaluationCount == 2
            }
        )

        #expect(didComplete)
        #expect(evaluationCount == 2)
        #expect(clock.recordedSleepDeadlines() == [.init(offset: .milliseconds(10))])
    }

    @Test("Sleeps only until the deadline and does not evaluate again")
    func stopsAtDeadlineWithoutFinalEvaluation() async {
        let clock = ManualTestClock()
        var evaluationCount = 0

        let didComplete = await waitUntil(
            timeout: .milliseconds(5),
            pollingInterval: .milliseconds(10),
            clock: clock,
            sleepUntil: { deadline in clock.recordSleepAndAdvance(to: deadline) },
            condition: {
                evaluationCount += 1
                return false
            }
        )

        #expect(!didComplete)
        #expect(evaluationCount == 1)
        #expect(clock.recordedSleepDeadlines() == [.init(offset: .milliseconds(5))])
    }

    @Test("Does not sleep or evaluate again when the condition reaches the deadline")
    func conditionReachesDeadline() async {
        let clock = ManualTestClock()
        var evaluationCount = 0

        let didComplete = await waitUntil(
            timeout: .milliseconds(5),
            pollingInterval: .milliseconds(1),
            clock: clock,
            sleepUntil: { deadline in clock.recordSleepAndAdvance(to: deadline) },
            condition: {
                evaluationCount += 1
                clock.advance(by: .milliseconds(5))
                return false
            }
        )

        #expect(!didComplete)
        #expect(evaluationCount == 1)
        #expect(clock.recordedSleepDeadlines().isEmpty)
    }

    @Test("A nonpositive timeout evaluates exactly once")
    func nonpositiveTimeoutEvaluatesOnce() async {
        let clock = ManualTestClock()
        var evaluationCount = 0

        let didComplete = await waitUntil(
            timeout: .zero,
            pollingInterval: .milliseconds(10),
            clock: clock,
            sleepUntil: { deadline in clock.recordSleepAndAdvance(to: deadline) },
            condition: {
                evaluationCount += 1
                return false
            }
        )

        #expect(!didComplete)
        #expect(evaluationCount == 1)
        #expect(clock.recordedSleepDeadlines().isEmpty)
    }

    @Test("A nonpositive polling interval evaluates exactly once")
    func nonpositivePollingIntervalEvaluatesOnce() async {
        let clock = ManualTestClock()
        var evaluationCount = 0

        let didComplete = await waitUntil(
            timeout: .seconds(1),
            pollingInterval: .zero,
            clock: clock,
            sleepUntil: { deadline in clock.recordSleepAndAdvance(to: deadline) },
            condition: {
                evaluationCount += 1
                return true
            }
        )

        #expect(didComplete)
        #expect(evaluationCount == 1)
        #expect(clock.recordedSleepDeadlines().isEmpty)
    }

    @Test("A task cancelled before waiting does not evaluate")
    func cancellationBeforeWaitingReturnsFalse() async {
        let clock = ManualTestClock()
        var evaluationCount = 0

        let task = Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            return await waitUntil(
                timeout: .seconds(1),
                pollingInterval: .milliseconds(10),
                clock: clock,
                sleepUntil: { deadline in clock.recordSleepAndAdvance(to: deadline) },
                condition: {
                    evaluationCount += 1
                    return true
                }
            )
        }

        #expect(!(await task.value))
        #expect(evaluationCount == 0)
    }

    @Test("Cancellation during sleep returns false")
    func cancellationDuringSleepReturnsFalse() async {
        let clock = ManualTestClock()
        let sleepRecorder = SleepCallRecorder<ManualTestInstant>()
        let task = Task { @MainActor in
            await waitUntil(
                timeout: .seconds(1),
                pollingInterval: .milliseconds(10),
                clock: clock,
                sleepUntil: { deadline in
                    await sleepRecorder.record(deadline)
                    try await Task.sleep(for: .seconds(60))
                },
                condition: { false }
            )
        }

        await sleepRecorder.waitForCall()
        task.cancel()

        #expect(!(await task.value))
    }

    @Test("A sleep failure returns false")
    func sleepFailureReturnsFalse() async {
        let clock = ManualTestClock()

        let didComplete = await waitUntil(
            timeout: .seconds(1),
            pollingInterval: .milliseconds(10),
            clock: clock,
            sleepUntil: { _ in throw ExpectedSleepError() },
            condition: { false }
        )

        #expect(!didComplete)
    }
}

private struct ExpectedSleepError: Error {}
