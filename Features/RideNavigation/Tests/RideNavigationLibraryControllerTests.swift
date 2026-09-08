import Foundation
@testable import RideNavigation
import Testing
import TestSupport

@MainActor
struct RideNavigationLibraryControllerTests {
    @Test("A failed deletion restores only its route while another deletion is pending")
    func concurrentDeletionsPreservePendingRemoval() async {
        let first = LibraryControllerTestRoutes.route(name: "First")
        let second = LibraryControllerTestRoutes.route(name: "Second")
        let repository = LibraryControllerRouteRepository(routes: [first, second])
        let controller = LibraryControllerTestFactory.makeController(repository: repository)
        controller.start()
        await controller.refreshTask?.value
        controller.deleteSavedRoute(id: first.id)
        controller.deleteSavedRoute(id: second.id)
        let firstDeletion = controller.deletionTasks[first.id]
        let secondDeletion = controller.deletionTasks[second.id]
        #expect(await waitUntil { await repository.pendingDeleteIDs.count == 2 })
        #expect(controller.snapshot.savedRoutes.isEmpty)
        await repository.failDelete(id: first.id)
        await firstDeletion?.value
        await controller.refreshTask?.value
        #expect(controller.snapshot.savedRoutes.map(\.id) == [first.id])
        #expect(controller.snapshot.errorMessage != nil)
        await repository.completeDelete(id: second.id)
        await secondDeletion?.value
        await controller.refreshTask?.value
        #expect(controller.snapshot.savedRoutes.map(\.id) == [first.id])
        controller.stop()
    }

    @Test("An old initial load cannot erase a newly saved route")
    func initialLoadCannotOverwriteSave() async {
        let route = LibraryControllerTestRoutes.route(name: "New route")
        let repository = LibraryControllerRouteRepository()
        let controller = LibraryControllerTestFactory.makeController(repository: repository)
        await repository.blockLoads()
        controller.start()
        #expect(await waitUntil { await repository.pendingLoadCount == 1 })
        let initialLoad = controller.refreshTask
        controller.saveCompletedRoute(route)
        let save = controller.completedSaveTask
        #expect(await waitUntil { await repository.pendingSaveCount == 1 })
        await repository.unblockLoads()
        await repository.completeSave()
        await save?.value
        await controller.refreshTask?.value
        #expect(controller.snapshot.savedRoutes.map(\.id) == [route.id])
        await repository.resumeLoad(routes: [])
        await initialLoad?.value
        #expect(controller.snapshot.savedRoutes.map(\.id) == [route.id])
        controller.stop()
    }

    @Test("An older refresh cannot resurrect a deleted route")
    func oldRefreshCannotUndoDeletion() async {
        let first = LibraryControllerTestRoutes.route(name: "First")
        let second = LibraryControllerTestRoutes.route(name: "Second")
        let repository = LibraryControllerRouteRepository(routes: [first, second])
        let controller = LibraryControllerTestFactory.makeController(repository: repository)
        controller.start()
        await controller.refreshTask?.value
        await repository.blockLoads()
        controller.refresh()
        #expect(await waitUntil { await repository.pendingLoadCount == 1 })
        let oldRefresh = controller.refreshTask
        controller.deleteSavedRoute(id: first.id)
        let deletion = controller.deletionTasks[first.id]
        #expect(await waitUntil { await repository.pendingDeleteIDs.contains(first.id) })
        await repository.completeDelete(id: first.id)
        await deletion?.value
        #expect(await waitUntil { await repository.pendingLoadCount == 2 })
        let latestRefresh = controller.refreshTask
        await repository.resumeLoad(at: 1, routes: [second])
        await latestRefresh?.value
        await repository.resumeLoad(routes: [first, second])
        await oldRefresh?.value
        #expect(controller.snapshot.savedRoutes.map(\.id) == [second.id])
        controller.stop()
    }

    @Test("A canceled deletion cannot clear a new deletion of the same route after restart")
    func oldDeletionCannotFinishNewLifecycleOperation() async {
        let route = LibraryControllerTestRoutes.route(name: "Route")
        let repository = LibraryControllerRouteRepository(routes: [route])
        let controller = LibraryControllerTestFactory.makeController(repository: repository)
        controller.start()
        await controller.refreshTask?.value
        controller.deleteSavedRoute(id: route.id)
        let previousDeletion = controller.deletionTasks[route.id]
        #expect(await waitUntil { await repository.pendingDeleteCount == 1 })
        controller.stop()
        controller.start()
        await controller.refreshTask?.value
        controller.deleteSavedRoute(id: route.id)
        let currentDeletion = controller.deletionTasks[route.id]
        #expect(await waitUntil { await repository.pendingDeleteCount == 2 })
        await repository.failDelete(id: route.id)
        await previousDeletion?.value
        #expect(controller.deletionTasks[route.id] != nil)
        #expect(controller.snapshot.errorMessage == nil)
        #expect(controller.snapshot.savedRoutes.isEmpty)
        await repository.completeDelete(id: route.id)
        await currentDeletion?.value
        await controller.refreshTask?.value
        #expect(controller.snapshot.savedRoutes.isEmpty)
        controller.stop()
    }
}
