import BikeDomain
@testable import ChargeControl
import Testing
import TestSupport

@MainActor
@Suite("Charge control state observation")
struct ChargeControlStateObservationTests {
    @Test("Observation registers synchronously and preserves replay and nested updates before consumption")
    func replayAndNestedUpdatesAreOrdered() async {
        let emitter = ChargeControlStateEmitter()
        let initialState = ChargeControlState(isVisible: true, isEnabled: true, phase: .ready)
        let session = ChargeControlSessionTestFactory.make(
            repository: ChargeControlRepository(),
            stateEmitter: emitter,
            initialState: initialState
        )
        let stream = session.observeState()
        #expect(emitter.subscriberCount == 1)

        session.setTarget(percent: 80)
        session.receive(BikeBatteryHealth())
        let recorder = ChargeControlStateRecorder()
        let task = Task {
            for await state in stream { recorder.record(state) }
        }
        defer { task.cancel() }

        #expect(await waitUntil { recorder.states.count == 4 })
        #expect(recorder.states.first == initialState)
        #expect(recorder.states.dropFirst().map(\.selectedTargetPercent) == [80, 80, 100])
        #expect(recorder.states.map(\.phase) == [.ready, .ready, .updating, .unavailable])
        #expect(recorder.states.last == ChargeControlState())
        task.cancel()
        await task.value
    }

    @Test("Preparation and telemetry inout updates are delivered without recreating the observer")
    func inoutUpdatesAndRestartReachExistingObserver() async {
        let session = ChargeControlSessionTestFactory.make(repository: ChargeControlRepository())
        let stream = session.observeState()
        let recorder = ChargeControlStateRecorder()
        let task = Task {
            for await state in stream { recorder.record(state) }
        }
        defer { task.cancel() }

        session.receive(ChargeControlFixtures.chargingHealth())
        #expect(await waitUntil { recorder.states.last?.isEnabled == true })
        #expect(recorder.states.contains { $0.phase == .preparing })
        session.receive(ChargeControlFixtures.chargingHealth(powerWatts: 1_500))
        #expect(await waitUntil { recorder.states.last?.confirmedWatts == 1_500 })

        await session.stopAndWait()
        #expect(await waitUntil { recorder.states.last == ChargeControlState() })
        session.receive(ChargeControlFixtures.chargingHealth(powerWatts: 1_700))
        #expect(await waitUntil {
            recorder.states.last?.isEnabled == true && recorder.states.last?.confirmedWatts == 1_700
        })

        task.cancel()
        await task.value
        await session.stopAndWait()
    }

    @Test("Cancelling one observer removes only its subscription")
    func cancellationRemovesOnlyCancelledObserver() async {
        let emitter = ChargeControlStateEmitter()
        let session = ChargeControlSessionTestFactory.make(
            repository: ChargeControlRepository(),
            stateEmitter: emitter
        )
        let firstStream = session.observeState()
        let secondStream = session.observeState()
        let firstRecorder = ChargeControlStateRecorder()
        let secondRecorder = ChargeControlStateRecorder()
        let firstTask = Task {
            for await state in firstStream { firstRecorder.record(state) }
        }
        let secondTask = Task {
            for await state in secondStream { secondRecorder.record(state) }
        }
        defer { firstTask.cancel(); secondTask.cancel() }
        #expect(await waitUntil { firstRecorder.states.count == 1 && secondRecorder.states.count == 1 })
        firstTask.cancel()
        await firstTask.value
        #expect(await waitUntil { emitter.subscriberCount == 1 })

        session.receive(ChargeControlFixtures.chargingHealth())
        #expect(await waitUntil { secondRecorder.states.last?.isEnabled == true })
        #expect(firstRecorder.states == [ChargeControlState()])
        secondTask.cancel()
        await secondTask.value
        #expect(await waitUntil { emitter.subscriberCount == 0 })
        await session.stopAndWait()
    }

    @Test("Releasing the session and its emitter finishes the stream")
    func deinitFinishesObservation() async {
        var session: ChargeControlSession? = ChargeControlSessionTestFactory.make(
            repository: ChargeControlRepository()
        )
        guard let stream = session?.observeState() else {
            Issue.record("Expected a session state stream")
            return
        }
        let recorder = ChargeControlStateRecorder()
        let task = Task {
            for await state in stream { recorder.record(state) }
            recorder.finish()
        }
        defer { task.cancel() }
        session = nil
        #expect(await waitUntil { recorder.isFinished })
        #expect(recorder.states == [ChargeControlState()])
        task.cancel()
        await task.value
    }
}
