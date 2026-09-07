@testable import RideNavigation
import Testing
import TestSupport

@MainActor
struct RideNavigationPlanningPresentationTests {
    @Test("A preference refresh still presents the initial preview when its first effect was superseded")
    func refreshBeforeFirstPresentationPerformsTransition() async throws {
        let fixture = RideNavigationViewModelFixture()
        let model = fixture.viewModel
        model.start()
        defer { model.stop() }
        try #require(await waitUntil { model.pendingSettings.confirmed != nil })
        let observation = model.planningObservationTask
        observation?.cancel()
        await observation?.value
        let controller = model.planningController
        let buffered = PlanningControllerUpdateRecorder(stream: controller.observe())
        let destination = PlanningControllerTestData.place(name: "Destination")
        let trail = LibraryControllerTestRoutes.route(name: "Previous trail")
        let plan = try #require(await model.activityController.dependencies.trailMapPreparer.prepare(
            route: trail, direction: .forward
        ))
        model.activityController.dependencies.trailMap.apply(plan)
        model.library.selectImportedRoute(id: trail.id)
        let previousLibraryContext = model.library.contextGeneration
        model.calculateRoadPreview(from: PlanningControllerTestData.origin, to: destination, showsSearchLoading: true)
        let firstPreview = controller.routeTask
        try #require(await waitUntil { await fixture.roadRouteCalculator.requestCount == 1 })
        await fixture.roadRouteCalculator.succeed(routes: [PlanningControllerTestData.roadRoute(name: "First")])
        await firstPreview?.value
        #expect(model.viewState.screen == .home)
        model.recalculatePreviewRoutes(from: PlanningControllerTestData.origin, to: destination)
        let refreshedPreview = controller.routeTask
        try #require(await waitUntil { await fixture.roadRouteCalculator.requestCount == 1 })
        buffered.start()
        try #require(await waitUntil { buffered.updates.contains { $0.effect == .previewReady } })
        let superseded = try #require(buffered.updates.first { $0.effect == .previewReady })
        #expect(!controller.accepts(superseded))
        model.startPlanningObservation(lifecycle: model.lifecycleGeneration)
        try #require(await waitUntil { buffered.isFinished })
        buffered.stop()
        await fixture.roadRouteCalculator.succeed(routes: [
            PlanningControllerTestData.roadRoute(name: "Updated"),
            PlanningControllerTestData.roadRoute(name: "Alternative")
        ])
        await refreshedPreview?.value
        try #require(await waitUntil {
            model.viewState.screen == .map && model.viewState.activity == .preview
                && model.viewState.roadRouteOptions.count == 2
        })
        #expect(model.viewState.screen == .map)
        #expect(model.viewState.activity == .preview)
        #expect(model.library.contextGeneration > previousLibraryContext)
        #expect(!model.library.snapshot.persistence.selectedRouteNeedsSave)
        #expect(model.activityController.dependencies.trailMap.overviewCoordinates.isEmpty)
    }

    @Test("Refreshing an already presented preview preserves unrelated library and trail state")
    func acknowledgedPreviewRefreshDoesNotRepeatInitialReset() async throws {
        let fixture = RideNavigationViewModelFixture()
        let model = fixture.viewModel
        model.start()
        defer { model.stop() }
        let destination = PlanningControllerTestData.place(name: "Destination")
        model.calculateRoadPreview(from: PlanningControllerTestData.origin, to: destination, showsSearchLoading: false)
        try #require(await waitUntil { await fixture.roadRouteCalculator.requestCount == 1 })
        await fixture.roadRouteCalculator.succeed(routes: [PlanningControllerTestData.roadRoute(name: "First")])
        try #require(await waitUntil { model.viewState.screen == .map && model.viewState.activity == .preview })
        let trail = LibraryControllerTestRoutes.route(name: "Retained trail")
        let plan = try #require(await model.activityController.dependencies.trailMapPreparer.prepare(
            route: trail, direction: .forward
        ))
        model.activityController.dependencies.trailMap.apply(plan)
        model.library.selectImportedRoute(id: trail.id)
        let previousLibraryContext = model.library.contextGeneration
        let previousCoordinates = model.activityController.dependencies.trailMap.overviewCoordinates
        model.cameraMode = .automatic
        model.recalculatePreviewRoutes(from: PlanningControllerTestData.origin, to: destination)
        let refresh = model.planningController.routeTask
        try #require(await waitUntil { await fixture.roadRouteCalculator.requestCount == 1 })
        await fixture.roadRouteCalculator.succeed(routes: [
            PlanningControllerTestData.roadRoute(name: "Updated"),
            PlanningControllerTestData.roadRoute(name: "Alternative")
        ])
        await refresh?.value
        try #require(await waitUntil {
            guard case .overview = model.cameraMode else { return false }
            return model.viewState.roadRouteOptions.count == 2
        })
        #expect(model.library.contextGeneration == previousLibraryContext)
        #expect(model.library.snapshot.persistence.selectedRouteNeedsSave)
        #expect(model.activityController.dependencies.trailMap.overviewCoordinates == previousCoordinates)
    }
}
