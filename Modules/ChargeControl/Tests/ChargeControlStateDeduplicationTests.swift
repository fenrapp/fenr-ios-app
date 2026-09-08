import BikeDomain
@testable import ChargeControl
import Testing
import TestSupport

@MainActor
@Suite("Charge control state deduplication")
struct ChargeControlStateDeduplicationTests {
    @Test("Identical telemetry is silent while each observer receives replay and all actual nested transitions")
    func identicalTelemetryPreservesReplayAndTransitions() async {
        let emitter = ChargeControlStateEmitter()
        let repository = ChargeControlRepository()
        let session = ChargeControlSessionTestFactory.make(repository: repository, stateEmitter: emitter)
        let health = ChargeControlFixtures.chargingHealth()
        session.receive(health)
        #expect(await waitUntil { session.state.isEnabled && session.state.phase == .ready })
        let initial = session.state
        let firstStream = session.observeState()
        for _ in 0 ..< 100 { session.receive(health) }
        let secondStream = session.observeState()
        #expect(emitter.subscriberCount == 2)

        session.setTarget(percent: 80)
        session.receive(BikeBatteryHealth())

        let firstRecorder = ChargeControlStateRecorder()
        let secondRecorder = ChargeControlStateRecorder()
        let firstTask = Task {
            for await state in firstStream { firstRecorder.record(state) }
        }
        let secondTask = Task {
            for await state in secondStream { secondRecorder.record(state) }
        }
        defer { firstTask.cancel(); secondTask.cancel() }
        #expect(await waitUntil {
            firstRecorder.states.last == ChargeControlState()
                && secondRecorder.states.last == ChargeControlState()
        })

        var selected = initial
        selected.selectedTargetPercent = 80
        var updating = selected
        updating.phase = .updating
        let expected = [initial, selected, updating, ChargeControlState()]
        #expect(firstRecorder.states == expected)
        #expect(secondRecorder.states == expected)
        #expect(await repository.prepareCount() == 1)
        #expect(await repository.writtenTargetValues().isEmpty)
        firstTask.cancel()
        secondTask.cancel()
        await firstTask.value
        await secondTask.value
        await session.stopAndWait()
    }

    @Test("Repeated unconfirmed telemetry stays blocked and a matching sample still confirms the write")
    func deduplicationPreservesConfirmationAndSiblingValues() async {
        let repository = ChargeControlRepository()
        let session = ChargeControlSessionTestFactory.make(
            repository: repository, debounceDelay: .zero, confirmationDelay: .seconds(30)
        )
        let originalHealth = ChargeControlFixtures.chargingHealth()
        session.receive(originalHealth)
        #expect(await waitUntil { session.state.isEnabled && session.state.phase == .ready })
        let stream = session.observeState()
        let recorder = ChargeControlStateRecorder()
        let observation = Task {
            for await state in stream { recorder.record(state) }
        }
        defer { observation.cancel() }

        session.setPowerLimit(watts: 1_500)
        #expect(await waitUntil { session.state.status == .confirming(.powerWatts(1_500)) })
        let unconfirmed = session.state
        for _ in 0 ..< 100 { session.receive(originalHealth) }
        #expect(session.state == unconfirmed)
        #expect(!session.state.canAcceptInput)
        session.setTarget(percent: 80)
        #expect(await repository.writtenTargetValues().isEmpty)

        let confirmedHealth = ChargeControlFixtures.chargingHealth(powerWatts: 1_500)
        session.receive(confirmedHealth)
        #expect(session.state.status == .confirmed(.powerWatts(1_500)))
        #expect(session.state.canAcceptInput)
        #expect(session.state.confirmedWatts == 1_500)
        #expect(session.state.confirmedTargetPercent == 100)
        #expect(session.state.selectedTargetPercent == 100)
        for _ in 0 ..< 100 { session.receive(confirmedHealth) }
        session.receive(BikeBatteryHealth())

        #expect(await waitUntil { recorder.states.last == ChargeControlState() })
        let statuses = recorder.states.map(\.status)
        #expect(statuses.contains(.confirming(.powerWatts(1_500))))
        #expect(statuses.contains(.confirmed(.powerWatts(1_500))))
        #expect(zip(recorder.states, recorder.states.dropFirst()).allSatisfy { pair in pair.0 != pair.1 })
        #expect(await repository.writtenPowerValues() == [1_500])
        #expect(await repository.writtenTargetValues().isEmpty)
        #expect(await repository.maximumConcurrentWriteCount() == 1)
        observation.cancel()
        await observation.value
        await session.stopAndWait()
    }
}
