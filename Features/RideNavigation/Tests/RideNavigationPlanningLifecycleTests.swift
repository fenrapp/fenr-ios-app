import Foundation
@testable import RideNavigation
import Testing
import TestSupport

@MainActor
struct RideNavigationPlanningLifecycleTests {
    @Test("A new external link ignores an older result or failure", arguments: [false, true])
    func newestExternalLinkWins(oldFails: Bool) async throws {
        let fixture = PlanningControllerTestFixture.make()
        let controller = fixture.controller
        let firstURL = URL(string: "https://example.com/first")!
        let secondURL = URL(string: "https://example.com/second")!
        let second = PlanningControllerTestData.place(name: "Second")
        controller.start()
        controller.resolveExternalLink(firstURL)
        let oldLink = controller.externalLinkTask
        try #require(await waitUntil { await fixture.linkResolver.hasRequest(for: firstURL) })
        controller.resolveExternalLink(secondURL)
        let newLink = controller.externalLinkTask
        try #require(await waitUntil { await fixture.linkResolver.hasRequest(for: secondURL) })
        await fixture.linkResolver.succeed(url: secondURL, destination: second)
        await newLink?.value
        if oldFails {
            await fixture.linkResolver.fail(url: firstURL)
        } else {
            await fixture.linkResolver.succeed(
                url: firstURL, destination: PlanningControllerTestData.place(name: "Old")
            )
        }
        await oldLink?.value
        #expect(controller.snapshot.pendingExternalDestination?.id == second.id)
        #expect(controller.snapshot.errorMessage == nil)
        controller.stop()
    }

    @Test("Selecting another trail invalidates both external-link and trail-exit requests")
    func newSelectionInvalidatesLinkAndExit() async throws {
        let fixture = PlanningControllerTestFixture.make()
        let controller = fixture.controller
        let url = URL(string: "https://example.com/old")!
        let selected = LibraryControllerTestRoutes.route(name: "New selection")
        controller.start()
        controller.selectTrailRoute(LibraryControllerTestRoutes.route(name: "Old selection"))
        controller.resolveExternalLink(url)
        controller.findTrailExit(from: PlanningControllerTestData.origin, preferences: .init())
        let link = controller.externalLinkTask
        let exit = controller.trailExitTask
        try #require(await waitUntil { await fixture.linkResolver.hasRequest(for: url) })
        try #require(await waitUntil { await fixture.exitFinder.requestCount == 1 })
        controller.selectTrailRoute(selected)
        await fixture.linkResolver.succeed(url: url, destination: PlanningControllerTestData.place(name: "Old"))
        await fixture.exitFinder.succeed(request: 0, exit: PlanningControllerTestData.trailExit(name: "Old exit"))
        await link?.value
        await exit?.value
        #expect(controller.snapshot.selectedRoute?.id == selected.id)
        #expect(controller.snapshot.pendingExternalDestination == nil)
        #expect(controller.snapshot.trailExitPreview == nil)
        #expect(!controller.snapshot.isFindingTrailExit)
        #expect(controller.snapshot.errorMessage == nil)
        controller.stop()
    }

    @Test("Stop and restart reject every old channel without clearing the new search")
    func restartRejectsOldChannels() async throws {
        let fixture = PlanningControllerTestFixture.make()
        let controller = fixture.controller
        let url = URL(string: "https://example.com/old")!
        controller.start()
        controller.selectTrailRoute(LibraryControllerTestRoutes.route(name: "Trail"))
        controller.approach(
            from: PlanningControllerTestData.origin, to: PlanningControllerTestData.place(name: "Approach"),
            preferences: .init()
        )
        controller.updateSearchQuery("Old query", near: nil)
        controller.resolveExternalLink(url)
        controller.findTrailExit(from: PlanningControllerTestData.origin, preferences: .init())
        let tasks = [controller.routeTask, controller.searchTask, controller.externalLinkTask, controller.trailExitTask]
        try #require(await waitUntil { await fixture.roadCalculator.requestCount == 1 })
        try #require(await waitUntil { await fixture.placeSearch.hasRequest(for: "Old query") })
        try #require(await waitUntil { await fixture.linkResolver.hasRequest(for: url) })
        try #require(await waitUntil { await fixture.exitFinder.requestCount == 1 })
        controller.stop()
        controller.start()
        controller.updateSearchQuery("New query", near: nil)
        let newSearch = controller.searchTask
        try #require(await waitUntil { await fixture.placeSearch.hasRequest(for: "New query") })
        await fixture.roadCalculator.succeed(routes: [PlanningControllerTestData.roadRoute(name: "Old road")])
        await fixture.placeSearch.fail(query: "Old query")
        await fixture.linkResolver.fail(url: url)
        await fixture.exitFinder.succeed(request: 0, exit: PlanningControllerTestData.trailExit(name: "Old exit"))
        for task in tasks { await task?.value }
        #expect(controller.snapshot.isSearching)
        #expect(controller.snapshot.roadRoute == nil)
        #expect(controller.snapshot.pendingExternalDestination == nil)
        #expect(controller.snapshot.trailExitPreview == nil && !controller.snapshot.isFindingTrailExit)
        #expect(controller.snapshot.errorMessage == nil)
        let destination = PlanningControllerTestData.place(name: "Current")
        await fixture.placeSearch.succeed(query: "New query", places: [destination])
        await newSearch?.value
        #expect(controller.snapshot.searchResults.map(\.id) == [destination.id])
        #expect(!controller.snapshot.isSearching)
        controller.stop()
    }
}
