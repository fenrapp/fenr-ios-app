import Foundation
@testable import RideNavigation
import RideNavigationDomain
import Testing
import TestSupport

@MainActor
struct RideNavigationLazyLibraryLifecycleTests {
    @Test("Discarding old geometry cleans its handle without clearing a newer selection", arguments: [false, true])
    func finishesDiscardedGeometry(replacesPending: Bool) async throws {
        let original = LibraryControllerTestRoutes.route(name: "Original")
        let updated = original.renamed("Updated", at: original.updatedAt.addingTimeInterval(1))
        try await LazyRouteRepositoryTestScope.run(summaries: [RideRouteSummary(original)]) { repository in
            let model = RideNavigationViewModelFixture(repository: repository).viewModel
            model.start()
            defer { model.stop() }
            try #require(await waitUntil { model.viewState.savedRoutes.count == 1 })
            model.openSavedRoute(id: original.id)
            let oldTask = try #require(model.savedRouteLoadingTask)
            try #require(await waitUntil { await repository.pendingIDs.count == 1 })
            await repository.save(updated)
            model.library.includeSavedRoute(updated)
            if replacesPending {
                model.openSavedRoute(id: updated.id)
                try #require(await waitUntil { await repository.pendingIDs.count == 2 })
            }
            await repository.complete(route: original)
            await oldTask.value
            #expect(model.planningController.snapshot.selectedRoute == nil)
            #expect(model.viewState.errorText == nil)
            #expect((model.savedRouteLoadingTask != nil) == replacesPending)
            if !replacesPending { model.openSavedRoute(id: updated.id) }
            let currentTask = try #require(model.savedRouteLoadingTask)
            try #require(await waitUntil { await repository.pendingIDs.count == 1 })
            await repository.complete(route: updated)
            await currentTask.value
            #expect(model.savedRouteLoadingTask == nil)
            #expect(model.planningController.snapshot.selectedRoute == updated)
        }
    }

    @Test("Discarding an old share cleans its handle without clearing a newer share", arguments: [false, true])
    func finishesDiscardedShare(replacesPending: Bool) async throws {
        let original = LibraryControllerTestRoutes.route(name: "Original")
        let updated = original.renamed("Updated", at: original.updatedAt.addingTimeInterval(1))
        try await LazyRouteRepositoryTestScope.run(summaries: [RideRouteSummary(original)]) { repository in
            let controller = LibraryControllerTestFactory.makeController(repository: repository)
            controller.start()
            defer { controller.stop() }
            try #require(await waitUntil { controller.snapshot.savedRoutes.count == 1 })
            controller.shareSavedRoute(id: original.id)
            let oldTask = try #require(controller.shareTask)
            try #require(await waitUntil { await repository.pendingIDs.count == 1 })
            await repository.save(updated)
            controller.includeSavedRoute(updated)
            if replacesPending {
                controller.shareSavedRoute(id: updated.id)
                try #require(await waitUntil { await repository.pendingIDs.count == 2 })
            }
            await repository.fail()
            await oldTask.value
            #expect(controller.snapshot.shareRequest == nil)
            #expect(controller.snapshot.errorMessage == nil)
            #expect((controller.shareTask != nil) == replacesPending)
            #expect(controller.sharingRouteID == (replacesPending ? updated.id : nil))
            if !replacesPending { controller.shareSavedRoute(id: updated.id) }
            let currentTask = try #require(controller.shareTask)
            try #require(await waitUntil { await repository.pendingIDs.count == 1 })
            await repository.complete(route: updated)
            await currentTask.value
            #expect(controller.shareTask == nil)
            #expect(controller.sharingRouteID == nil)
            #expect(controller.snapshot.shareRequest?.filename == "Updated.gpx")
        }
    }

    @Test("A pending geometry read does not retain its view model and is cancelled on release")
    func releasesViewModelDuringGeometryRead() async throws {
        let route = LibraryControllerTestRoutes.route(name: "Saved")
        try await LazyRouteRepositoryTestScope.run(summaries: [RideRouteSummary(route)]) { repository in
            var model: RideNavigationViewModel? = RideNavigationViewModelFixture(repository: repository).viewModel
            weak var released = model
            model?.start()
            try #require(await waitUntil { model?.viewState.savedRoutes.count == 1 })
            model?.openSavedRoute(id: route.id)
            let task = try #require(model?.savedRouteLoadingTask)
            try #require(await waitUntil { await repository.pendingIDs.count == 1 })
            model = nil
            #expect(await waitUntil { released == nil })
            #expect(task.isCancelled)
            await repository.complete(route: route)
            await task.value
            #expect(await repository.pendingIDs.isEmpty)
        }
    }

    @Test("A pending share read does not retain its controller and is cancelled on release")
    func releasesLibraryDuringShareRead() async throws {
        let route = LibraryControllerTestRoutes.route(name: "Saved")
        try await LazyRouteRepositoryTestScope.run(summaries: [RideRouteSummary(route)]) { repository in
            var controller: RideNavigationLibraryController? = LibraryControllerTestFactory.makeController(
                repository: repository
            )
            weak var released = controller
            controller?.start()
            try #require(await waitUntil { controller?.snapshot.savedRoutes.count == 1 })
            controller?.shareSavedRoute(id: route.id)
            let task = try #require(controller?.shareTask)
            try #require(await waitUntil { await repository.pendingIDs.count == 1 })
            controller = nil
            #expect(await waitUntil { released == nil })
            #expect(task.isCancelled)
            await repository.complete(route: route)
            await task.value
            #expect(await repository.pendingIDs.isEmpty)
        }
    }
}
