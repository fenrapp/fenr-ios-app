import BikeDomain
import Observation
import Testing
import TestSupport
@testable import WatchOnboarding

@MainActor
struct WatchOnboardingObservationTests {
    @Test("Restarting onboarding observes new events once and repeated starts retain one set of subscriptions")
    func restartKeepsSingleObservationLifecycle() async throws {
        let repository = WatchOnboardingRepository()
        let model = WatchOnboardingTestFactory.make(repository: repository)
        defer { model.stop() }
        model.start()
        model.start()
        try #require(await waitUntil { await repository.discoveryStartCount() == 1 })
        await repository.sendDebugEvent(.init(title: "Old lifecycle", detail: "Before stop"))
        try #require(await waitUntil { model.viewState.debugEvents.count == 1 })
        model.stop()
        try #require(await waitUntil { await repository.discoveryStopCount() == 1 })
        model.start()
        model.start()
        try #require(await waitUntil {
            let connections = await repository.connectionObservationCount
            let debug = await repository.debugObservationCount
            let discoveries = await repository.discoveryObservationCount
            return connections == 2 && debug == 2 && discoveries == 2
        })
        #expect(model.viewState.debugEvents.isEmpty)
        let recorder = WatchObservationRecorder()
        withObservationTracking {
            _ = model.viewState.debugEvents
        } onChange: {
            recorder.record()
        }
        let event = BikeDebugEvent(title: "Current lifecycle", detail: "After restart")
        await repository.sendDebugEvent(event)
        try #require(await waitUntil { model.viewState.debugEvents.first?.id == event.id })
        #expect(model.viewState.debugEvents.count == 1)
        #expect(recorder.count == 1)
        #expect(await repository.discoveryStartCount() == 2)
    }
}
