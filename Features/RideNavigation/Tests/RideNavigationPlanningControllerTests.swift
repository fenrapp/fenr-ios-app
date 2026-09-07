@testable import RideNavigation
import Testing
import TestSupport

@MainActor
struct RideNavigationPlanningControllerTests {
    @Test("A newer query ignores an old search result or error", arguments: [false, true])
    func newestQueryWins(oldFails: Bool) async throws {
        let fixture = PlanningControllerTestFixture.make()
        let controller = fixture.controller
        controller.start()
        controller.updateSearchQuery("First", near: nil)
        let oldSearch = controller.searchTask
        try #require(await waitUntil { await fixture.placeSearch.hasRequest(for: "First") })
        controller.updateSearchQuery("Second", near: nil)
        let newSearch = controller.searchTask
        try #require(await waitUntil { await fixture.placeSearch.hasRequest(for: "Second") })
        let destination = PlanningControllerTestData.place(name: "Second")
        await fixture.placeSearch.succeed(query: "Second", places: [destination])
        await newSearch?.value
        if oldFails {
            await fixture.placeSearch.fail(query: "First")
        } else {
            await fixture.placeSearch.succeed(query: "First", places: [PlanningControllerTestData.place(name: "Old")])
        }
        await oldSearch?.value
        #expect(controller.snapshot.searchResults.map(\.id) == [destination.id])
        #expect(!controller.snapshot.isSearching)
        #expect(controller.snapshot.errorMessage == nil)
        controller.stop()
    }

    @Test("A new destination supersedes an older reroute with its own preferences", arguments: [false, true])
    func newDestinationBeatsReroute(oldFails: Bool) async throws {
        let fixture = PlanningControllerTestFixture.make()
        let controller = fixture.controller
        let first = PlanningControllerTestData.place(name: "First")
        let second = PlanningControllerTestData.place(name: "Second")
        controller.start()
        controller.preview(
            from: PlanningControllerTestData.origin, to: first, preferences: .init(), showsSearchLoading: false
        )
        try #require(await waitUntil { await fixture.roadCalculator.requestCount == 1 })
        let initial = controller.routeTask
        await fixture.roadCalculator.succeed(routes: [PlanningControllerTestData.roadRoute(name: "Initial")])
        await initial?.value
        controller.reroute(from: PlanningControllerTestData.origin, preferences: .init())
        let oldReroute = controller.routeTask
        try #require(await waitUntil { await fixture.roadCalculator.requestCount == 1 })
        controller.preview(
            from: PlanningControllerTestData.origin, to: second,
            preferences: .init(avoidsTolls: true, avoidsHighways: true), showsSearchLoading: true
        )
        let newPreview = controller.routeTask
        try #require(await waitUntil { await fixture.roadCalculator.requestCount == 2 })
        #expect(await fixture.roadCalculator.lastPreferences == .init(avoidsTolls: true, avoidsHighways: true))
        await fixture.roadCalculator.succeed(request: 1, routes: [PlanningControllerTestData.roadRoute(name: "New")])
        await newPreview?.value
        if oldFails {
            await fixture.roadCalculator.fail(request: 0)
        } else {
            await fixture.roadCalculator.succeed(
                request: 0, routes: [PlanningControllerTestData.roadRoute(name: "Old")]
            )
        }
        await oldReroute?.value
        #expect(controller.snapshot.selectedDestination?.id == second.id)
        #expect(controller.snapshot.roadRoute?.name == "New")
        #expect(!controller.snapshot.isRerouting && !controller.snapshot.isCalculatingRoadRoutes)
        #expect(!controller.snapshot.isSearching && controller.snapshot.errorMessage == nil)
        controller.stop()
    }

    @Test("A superseded preview effect already in the stream buffer is rejected", arguments: [false, true])
    func rejectsBufferedEffect(changesContext: Bool) async throws {
        let fixture = PlanningControllerTestFixture.make()
        let controller = fixture.controller
        let recorder = PlanningControllerUpdateRecorder(stream: controller.observe())
        controller.start()
        controller.preview(
            from: PlanningControllerTestData.origin, to: PlanningControllerTestData.place(name: "First"),
            preferences: .init(), showsSearchLoading: false
        )
        let firstTask = controller.routeTask
        try #require(await waitUntil { await fixture.roadCalculator.requestCount == 1 })
        await fixture.roadCalculator.succeed(routes: [PlanningControllerTestData.roadRoute(name: "Old")])
        await firstTask?.value
        if changesContext {
            controller.preview(
                from: PlanningControllerTestData.origin, to: PlanningControllerTestData.place(name: "Second"),
                preferences: .init(), showsSearchLoading: false
            )
        } else {
            controller.recalculatePreview(
                from: PlanningControllerTestData.origin, to: PlanningControllerTestData.place(name: "First"),
                preferences: .init(avoidsTolls: true)
            )
        }
        let secondTask = controller.routeTask
        try #require(await waitUntil { await fixture.roadCalculator.requestCount == 1 })
        recorder.start()
        try #require(await waitUntil { recorder.updates.contains { $0.effect == .previewReady } })
        let staleUpdate = try #require(recorder.updates.first { $0.effect == .previewReady })
        #expect(staleUpdate.snapshot.roadRoute?.name == "Old")
        #expect(!controller.accepts(staleUpdate))
        await fixture.roadCalculator.succeed(routes: [PlanningControllerTestData.roadRoute(name: "New")])
        await secondTask?.value
        try #require(await waitUntil { recorder.updates.filter { $0.effect != nil }.count == 2 })
        let currentUpdate = try #require(recorder.updates.last { $0.effect != nil })
        #expect(controller.accepts(currentUpdate))
        #expect(currentUpdate.snapshot.roadRoute?.name == "New")
        controller.stop()
        #expect(await waitUntil { recorder.isFinished })
        recorder.stop()
    }
}
