@testable import BikeDemo
import Observation
import Testing
import TestSupport

@MainActor
struct BikeDemoSelectionLifecycleTests {
    @Test("Stop joins a non-cooperative selection without publishing it and allows a fresh selection")
    func stopSuppressesOldResultAndAllowsRestart() async throws {
        let fixture = BikeDemoTestFixture.make()
        defer { fixture.gate.finish() }
        let recorder = fixture.recorder
        withObservationTracking {
            _ = fixture.model.viewState.selectedID
        } onChange: {
            recorder.recordObservation()
        }
        fixture.model.select(id: "riding")
        try #require(await waitUntil { fixture.gate.requestCount == 1 })
        let stopping = Task { await fixture.model.stop() }
        defer { stopping.cancel() }
        try #require(await waitUntil { fixture.gate.cancellationCount == 1 })
        fixture.gate.resumeNext()
        await stopping.value
        #expect(fixture.model.viewState.selectedID == "parked")
        #expect(recorder.observationCount == 0)

        fixture.model.select(id: "charging")
        try #require(await waitUntil { fixture.gate.requestCount == 2 })
        fixture.gate.resumeNext()
        try #require(await waitUntil { fixture.model.viewState.selectedID == "charging" })
        await fixture.model.stop()
        #expect(recorder.observationCount == 1)
        #expect(await fixture.repository.currentScenario() == .charging)
    }

    @Test("A finishing stop retains ownership of a selection accepted while the old selection was suspended")
    func overlappingStopKeepsNewSelectionCancelable() async throws {
        let fixture = BikeDemoTestFixture.make()
        defer { fixture.gate.finish() }
        fixture.model.select(id: "riding")
        try #require(await waitUntil { fixture.gate.requestCount == 1 })
        let firstStop = Task { await fixture.model.stop() }
        defer { firstStop.cancel() }
        try #require(await waitUntil { fixture.gate.cancellationCount == 1 })
        fixture.model.select(id: "charging")
        fixture.gate.resumeNext()
        await firstStop.value
        try #require(await waitUntil { fixture.gate.requestCount == 2 })
        let secondStop = Task { await fixture.model.stop() }
        defer { secondStop.cancel() }
        try #require(await waitUntil { fixture.gate.cancellationCount == 2 })
        fixture.gate.resumeNext()
        await secondStop.value
        #expect(fixture.model.viewState.selectedID == "parked")
        #expect(fixture.recorder.scenarios == [.riding, .charging])
    }
}
