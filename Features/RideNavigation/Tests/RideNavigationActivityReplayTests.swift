@testable import RideNavigation
import Testing
import TestSupport

@MainActor
struct RideNavigationActivityReplayTests {
    @Test("A completion buffered before stop is presented after restart without losing or saving the recording twice")
    func restartPresentsBufferedCompletion() async throws {
        let timing = ControllableRideNavigationTiming()
        let repository = LibraryControllerRouteRepository()
        let fixture = RideNavigationViewModelFixture(repository: repository, timing: timing.makeTiming())
        let model = fixture.viewModel
        model.start()
        defer { model.stop() }
        try #require(await waitUntil { model.pendingSettings.confirmed != nil })
        model.startRecording()
        model.activityController.receiveLocation(
            ActivityControllerTestData.location(index: 0, seconds: 0), speedKilometersPerHour: 18, preferences: .init()
        )
        model.activityController.receiveLocation(
            ActivityControllerTestData.location(index: 1, seconds: 5), speedKilometersPerHour: 18, preferences: .init()
        )
        model.activityObservationTask?.cancel()
        await model.activityObservationTask?.value
        _ = model.activityController.finishActivity()
        let recording = try #require(model.activityController.snapshot.completedRecording)
        #expect(model.screen == .map)
        model.stop()
        model.start()
        try #require(await waitUntil { model.viewState.screen == .summary })
        #expect(model.viewState.canSaveCompletedRoute)
        #expect(model.activityController.snapshot.completedRecording?.id == recording.id)
        #expect(model.activityController.snapshot.completedRecording?.points.count == 2)
        #expect(await repository.savedRoutes.isEmpty)
        model.stop()
        model.start()
        model.saveCompletedRouteAndClose(name: "Saved replay")
        try #require(await waitUntil { await repository.pendingSaveCount == 1 })
        await repository.completeSave()
        try #require(await waitUntil { model.viewState.screen == .home })
        #expect(await repository.savedRoutes.map(\.id) == [recording.id])
        #expect(await repository.pendingSaveCount == 0)
    }

    @Test("A new recording invalidates an older buffered completion across restart")
    func newRecordingRejectsOldTerminalEffect() async throws {
        let timing = ControllableRideNavigationTiming()
        let fixture = RideNavigationViewModelFixture(timing: timing.makeTiming())
        let model = fixture.viewModel
        model.start()
        defer { model.stop() }
        try #require(await waitUntil { model.pendingSettings.confirmed != nil })
        model.startRecording()
        model.activityController.receiveLocation(
            ActivityControllerTestData.location(index: 0, seconds: 0), speedKilometersPerHour: 18, preferences: .init()
        )
        model.activityController.receiveLocation(
            ActivityControllerTestData.location(index: 1, seconds: 5), speedKilometersPerHour: 18, preferences: .init()
        )
        model.activityObservationTask?.cancel()
        await model.activityObservationTask?.value
        let oldCompletion = try #require(model.activityController.finishActivity())
        model.stop()
        _ = model.activityController.startRecording(name: "New recording")
        model.start()
        try #require(await waitUntil { model.viewState.screen == .map && model.viewState.activity == .recording })
        #expect(model.activityController.snapshot.completedRecording == nil)
        #expect(model.activityController.snapshot.completion == nil)
        #expect(!model.activityController.accepts(oldCompletion))
        model.receiveActivityUpdate(oldCompletion)
        #expect(model.viewState.screen == .map && model.viewState.activity == .recording)
        #expect(model.activityController.snapshot.completedRecording == nil)
    }
}
