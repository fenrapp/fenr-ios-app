@testable import BikeDemo
import Observation
import Testing
import TestSupport

@MainActor
struct BikeDemoObservationTests {
    @Test("Scenario selection invalidates tracked presentation after each completed selection")
    func observesSelectionChanges() async throws {
        let fixture = BikeDemoTestFixture.make()
        defer { fixture.gate.finish() }
        let recorder = fixture.recorder
        let initialRows = fixture.model.viewState.scenarios
        for (index, id) in ["riding", "charging"].enumerated() {
            withObservationTracking {
                _ = fixture.model.viewState.selectedID
            } onChange: {
                recorder.recordObservation()
            }
            fixture.model.select(id: id)
            try #require(await waitUntil { fixture.gate.requestCount == index + 1 })
            #expect(recorder.observationCount == index)
            fixture.gate.resumeNext()
            try #require(await waitUntil { fixture.model.viewState.selectedID == id })
            #expect(recorder.observationCount == index + 1)
            #expect(fixture.model.viewState.scenarios == initialRows)
        }
        await fixture.model.stop()
        #expect(await fixture.repository.currentScenario() == .charging)
    }

    @Test("Rapid selection serializes the latest write and suppresses cancelled intermediate presentation")
    func rapidSelectionKeepsLatestScenario() async throws {
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
        fixture.model.select(id: "charging")
        fixture.model.select(id: "cellAnomaly")
        #expect(fixture.recorder.scenarios == [.riding])
        fixture.gate.resumeNext()
        try #require(await waitUntil { fixture.gate.requestCount == 2 })
        #expect(fixture.recorder.scenarios == [.riding, .cellAnomaly])
        #expect(fixture.model.viewState.selectedID == "parked")
        #expect(recorder.observationCount == 0)
        fixture.gate.resumeNext()
        try #require(await waitUntil { fixture.model.viewState.selectedID == "cellAnomaly" })
        await fixture.model.stop()
        #expect(recorder.observationCount == 1)
        #expect(await fixture.repository.currentScenario() == .cellAnomaly)
    }
}
