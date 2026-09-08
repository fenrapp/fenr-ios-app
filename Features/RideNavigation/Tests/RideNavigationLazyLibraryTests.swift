import Foundation
@testable import RideNavigation
import RideNavigationDomain
import Testing
import TestSupport
import VehicleSession

@MainActor
struct RideNavigationLazyLibraryTests {
    @Test("Opening a library decodes no route; only the latest selected route may open")
    func loadsOnlyTheSelectedGeometry() async throws {
        let first = LibraryControllerTestRoutes.route(name: "First")
        let second = LibraryControllerTestRoutes.route(name: "Second")
        let summaries = [first, second].map(RideRouteSummary.init)
        try await LazyRouteRepositoryTestScope.run(summaries: summaries) { repository in
            let model = RideNavigationViewModelFixture(repository: repository).viewModel
            model.start()
            defer { model.stop() }
            try #require(await waitUntil { model.viewState.savedRoutes.count == 2 })
            #expect(await repository.detailLoadCount == 0)
            model.openSavedRoute(id: first.id)
            let oldTask = model.savedRouteLoadingTask
            try #require(await waitUntil { await repository.pendingIDs == [first.id] })
            model.openSavedRoute(id: second.id)
            let currentTask = model.savedRouteLoadingTask
            try #require(await waitUntil { await repository.pendingIDs == [first.id, second.id] })
            await repository.complete(route: first)
            await oldTask?.value
            #expect(model.planningController.snapshot.selectedRoute == nil)
            await repository.complete(route: second)
            await currentTask?.value
            #expect(model.planningController.snapshot.selectedRoute == second)
            #expect(model.viewState.screen == .map)
            #expect(await repository.detailLoadCount == 2)
        }
    }

    @Test("Late geometry cannot replace recording or publish after stop", arguments: [false, true])
    func rejectsGeometryAfterContextEnds(stop: Bool) async throws {
        let route = LibraryControllerTestRoutes.route(name: "Saved route")
        try await LazyRouteRepositoryTestScope.run(summaries: [RideRouteSummary(route)]) { repository in
            let model = RideNavigationViewModelFixture(repository: repository).viewModel
            model.start()
            defer { model.stop() }
            try #require(await waitUntil { model.viewState.savedRoutes.count == 1 })
            model.openSavedRoute(id: route.id)
            let task = model.savedRouteLoadingTask
            try #require(await waitUntil { await repository.pendingIDs == [route.id] })
            if stop {
                model.stop()
                model.start()
            } else {
                model.startRecording()
            }
            await repository.complete(route: route)
            await task?.value
            #expect(model.planningController.snapshot.selectedRoute == nil)
            if !stop { #expect(model.activityController.snapshot.activity == .recording) }
        }
    }

    @Test("An unreadable selected route reports an error and another tap retries")
    func failedReadCanRetryWithoutLosingTheLibrary() async throws {
        let route = LibraryControllerTestRoutes.route(name: "Saved route")
        try await LazyRouteRepositoryTestScope.run(summaries: [RideRouteSummary(route)]) { repository in
            let model = RideNavigationViewModelFixture(repository: repository).viewModel
            model.start()
            defer { model.stop() }
            try #require(await waitUntil { model.viewState.savedRoutes.count == 1 })
            model.openSavedRoute(id: route.id)
            let failedTask = model.savedRouteLoadingTask
            try #require(await waitUntil { await repository.pendingIDs.count == 1 })
            await repository.fail()
            await failedTask?.value
            #expect(model.viewState.errorText != nil)
            #expect(model.viewState.savedRoutes.map(\.id) == [route.id])
            model.openSavedRoute(id: route.id)
            let retry = model.savedRouteLoadingTask
            try #require(await waitUntil { await repository.pendingIDs.count == 1 })
            await repository.complete(route: route)
            await retry?.value
            #expect(model.viewState.errorText == nil)
            #expect(model.planningController.snapshot.selectedRoute == route)
        }
    }

    @Test("A lazy share is discarded when its item is deleted or its presentation stops", arguments: [false, true])
    func rejectsLateShare(stop: Bool) async throws {
        let route = LibraryControllerTestRoutes.route(name: "Saved route")
        try await LazyRouteRepositoryTestScope.run(summaries: [RideRouteSummary(route)]) { repository in
            let controller = LibraryControllerTestFactory.makeController(repository: repository)
            controller.start()
            defer { controller.stop() }
            try #require(await waitUntil { controller.snapshot.savedRoutes.count == 1 })
            controller.shareSavedRoute(id: route.id)
            let task = controller.shareTask
            try #require(await waitUntil { await repository.pendingIDs.count == 1 })
            if stop { controller.stop() } else { controller.deleteSavedRoute(id: route.id) }
            await repository.complete(route: route)
            await task?.value
            #expect(controller.snapshot.shareRequest == nil)
            #expect(controller.snapshot.errorMessage == nil)
        }
    }

    @Test("Replacing the same saved ID rejects an older pending share", arguments: [false, true])
    func rejectsSameIDReplacement(fails: Bool) async throws {
        let route = LibraryControllerTestRoutes.route(name: "Saved route")
        try await LazyRouteRepositoryTestScope.run(summaries: [RideRouteSummary(route)]) { repository in
            let controller = LibraryControllerTestFactory.makeController(repository: repository)
            controller.start()
            defer { controller.stop() }
            try #require(await waitUntil { controller.snapshot.savedRoutes.count == 1 })
            controller.shareSavedRoute(id: route.id)
            let task = controller.shareTask
            try #require(await waitUntil { await repository.pendingIDs.count == 1 })
            let updated = route.renamed("Updated", at: route.updatedAt.addingTimeInterval(1))
            controller.includeSavedRoute(updated)
            if fails { await repository.fail() } else { await repository.complete(route: route) }
            await task?.value
            #expect(controller.snapshot.shareRequest == nil)
            #expect(controller.snapshot.savedRoutes.first?.name == "Updated")
            #expect(controller.snapshot.errorMessage == nil)
        }
    }

    @Test("Library rows reuse their storage through unrelated renders and invalidate for units and writes")
    func cachesRowsByLibraryRevisionAndUnits() async throws {
        let route = LibraryControllerTestRoutes.route(name: "Saved route")
        try await LazyRouteRepositoryTestScope.run(summaries: [RideRouteSummary(route)]) { repository in
            let fixture = RideNavigationViewModelFixture(repository: repository)
            let model = fixture.viewModel
            model.start()
            defer { model.stop() }
            try #require(await waitUntil { model.viewState.savedRoutes.count == 1 })
            try #require(await waitUntil { await fixture.vehicleSession.activeObserverCount() == 1 })
            var settings = model.vehicleSnapshot.settings
            settings.measurementSystem = .metric
            await fixture.vehicleSession.send(VehicleSessionSnapshot(settings: settings))
            try #require(await waitUntil { model.measurementSystem == .metric })
            let initial = model.routeRows
            let address = initial.withUnsafeBufferPointer { $0.baseAddress }
            for _ in 0 ..< 100 {
                model.render()
                #expect(model.routeRows.withUnsafeBufferPointer { $0.baseAddress } == address)
            }
            settings.measurementSystem = .imperial
            await fixture.vehicleSession.send(VehicleSessionSnapshot(settings: settings))
            try #require(await waitUntil { model.measurementSystem == .imperial })
            let newUnits = model.routeRows
            #expect(newUnits.first?.detail != initial.first?.detail)
            let updated = route.renamed("New name", at: route.updatedAt.addingTimeInterval(1))
            model.library.includeSavedRoute(updated)
            #expect(model.routeRows.first?.title == "New name")
            #expect(await repository.detailLoadCount == 0)
        }
    }
}
