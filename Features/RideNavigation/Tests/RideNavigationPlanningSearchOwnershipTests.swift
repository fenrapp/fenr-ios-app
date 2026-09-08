@testable import RideNavigation
import Testing
import TestSupport

@MainActor
struct RideNavigationPlanningSearchOwnershipTests {
    @Test("Editing the query cancels an old preview without canceling the new search spinner")
    func newQueryCancelsPendingPreview() async throws {
        let fixture = PlanningControllerTestFixture.make()
        let controller = fixture.controller
        controller.start()
        controller.preview(
            from: PlanningControllerTestData.origin, to: PlanningControllerTestData.place(name: "Old"),
            preferences: .init(), showsSearchLoading: true
        )
        let preview = controller.routeTask
        try #require(await waitUntil { await fixture.roadCalculator.requestCount == 1 })
        controller.updateSearchQuery("New query", near: nil)
        let search = controller.searchTask
        try #require(await waitUntil { await fixture.placeSearch.hasRequest(for: "New query") })
        #expect(controller.snapshot.isSearching)
        await fixture.roadCalculator.succeed(routes: [PlanningControllerTestData.roadRoute(name: "Old")])
        await preview?.value
        #expect(controller.snapshot.roadRoute == nil)
        #expect(controller.snapshot.selectedDestination == nil)
        #expect(controller.snapshot.isSearching)
        #expect(!controller.snapshot.isCalculatingRoadRoutes)
        controller.cancel(.road)
        #expect(controller.snapshot.isSearching)
        let destination = PlanningControllerTestData.place(name: "Current")
        await fixture.placeSearch.succeed(query: "New query", places: [destination])
        await search?.value
        #expect(!controller.snapshot.isSearching)
        #expect(controller.snapshot.searchResults.map(\.id) == [destination.id])
        controller.stop()
    }

    @Test("Editing the query invalidates a preview-ready effect already buffered for the UI")
    func newQueryRejectsBufferedPreview() async throws {
        let fixture = PlanningControllerTestFixture.make()
        let controller = fixture.controller
        let recorder = PlanningControllerUpdateRecorder(stream: controller.observe())
        controller.start()
        controller.preview(
            from: PlanningControllerTestData.origin, to: PlanningControllerTestData.place(name: "Old"),
            preferences: .init(), showsSearchLoading: true
        )
        let preview = controller.routeTask
        try #require(await waitUntil { await fixture.roadCalculator.requestCount == 1 })
        await fixture.roadCalculator.succeed(routes: [PlanningControllerTestData.roadRoute(name: "Old")])
        await preview?.value
        controller.updateSearchQuery("New query", near: nil)
        let search = controller.searchTask
        try #require(await waitUntil { await fixture.placeSearch.hasRequest(for: "New query") })
        recorder.start()
        try #require(await waitUntil { recorder.updates.contains { $0.effect == .previewReady } })
        let oldEffect = try #require(recorder.updates.first { $0.effect == .previewReady })
        #expect(!controller.accepts(oldEffect))
        #expect(controller.snapshot.isSearching)
        await fixture.placeSearch.succeed(
            query: "New query", places: [PlanningControllerTestData.place(name: "Current")]
        )
        await search?.value
        #expect(!controller.snapshot.isSearching)
        controller.stop()
        #expect(await waitUntil { recorder.isFinished })
        recorder.stop()
    }

    @Test("Finishing navigation route work leaves an independent search loading", arguments: [false, true])
    func navigationCompletionPreservesSearchLoading(isReroute: Bool) async throws {
        let fixture = PlanningControllerTestFixture.make()
        let controller = fixture.controller
        let destination = PlanningControllerTestData.place(name: "Navigation")
        controller.start()
        if isReroute {
            controller.prepareExternalDestination(destination)
            controller.reroute(from: PlanningControllerTestData.origin, preferences: .init())
        } else {
            controller.approach(from: PlanningControllerTestData.origin, to: destination, preferences: .init())
        }
        let roadTask = controller.routeTask
        try #require(await waitUntil { await fixture.roadCalculator.requestCount == 1 })
        controller.updateSearchQuery("New query", near: nil)
        let searchTask = controller.searchTask
        try #require(await waitUntil { await fixture.placeSearch.hasRequest(for: "New query") })
        await fixture.roadCalculator.succeed(routes: [PlanningControllerTestData.roadRoute(name: "Navigation")])
        await roadTask?.value
        #expect(controller.snapshot.roadRoute?.name == "Navigation")
        #expect(controller.snapshot.isSearching)
        #expect(!controller.snapshot.isRerouting && !controller.snapshot.isCalculatingRoadRoutes)
        await fixture.placeSearch.succeed(query: "New query", places: [destination])
        await searchTask?.value
        #expect(!controller.snapshot.isSearching)
        controller.stop()
    }
}
