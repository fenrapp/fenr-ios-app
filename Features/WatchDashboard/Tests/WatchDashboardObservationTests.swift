import BikeDomain
import Observation
import Testing
import TestSupport
@testable import WatchDashboard

@MainActor
struct WatchDashboardObservationTests {
    @Test("Debug events independently invalidate the unavailable dashboard without changing its telemetry")
    func observesSecondaryDebugEvents() async throws {
        let repository = WatchDashboardRepository()
        let model = WatchDashboardTestFactory.make(repository: repository)
        defer { model.stop() }
        model.start()
        let recorder = WatchObservationRecorder()
        withObservationTracking {
            _ = model.debugEvents
        } onChange: {
            recorder.record()
        }
        let event = BikeDebugEvent(title: "Watch Bluetooth", detail: "Synthetic discovery event")
        await repository.send(event)
        try #require(await waitUntil { model.debugEvents.first?.id == event.id })
        #expect(recorder.count == 1)
        #expect(model.debugEvents.count == 1)
        if case .unavailable = model.viewState.mode {} else {
            Issue.record("A debug event must not publish a ride or charging state")
        }
    }
}
