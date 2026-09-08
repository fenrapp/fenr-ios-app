@testable import RideNavigation
import Testing
import TestSupport

@MainActor
struct RideNavigationLibraryLifecycleTests {
    @Test("An accepted completed save survives stop without replaying a close effect")
    func completedSaveSurvivesStop() async {
        let route = LibraryControllerTestRoutes.route(name: "Completed")
        let repository = LibraryControllerRouteRepository()
        let controller = LibraryControllerTestFactory.makeController(repository: repository)
        controller.start()
        await controller.refreshTask?.value
        controller.saveCompletedRoute(route, closeAfterSave: true)
        let save = controller.completedSaveTask
        #expect(await waitUntil { await repository.pendingSaveCount == 1 })
        controller.stop()
        await repository.completeSave()
        await save?.value
        #expect(await repository.saveCancellationStates == [false])
        #expect(controller.snapshot.persistence.status == .saved)
        let recorder = LibraryControllerUpdateRecorder(stream: controller.observe())
        recorder.start()
        controller.start()
        await controller.refreshTask?.value
        controller.stop()
        #expect(await waitUntil { recorder.isFinished })
        #expect(recorder.effects.isEmpty)
        #expect(controller.snapshot.savedRoutes.map(\.id) == [route.id])
        recorder.stop()
    }

    @Test("A previous lifecycle cannot close a restarted presentation")
    func completedSaveDoesNotCloseAfterRestart() async {
        let route = LibraryControllerTestRoutes.route(name: "Completed")
        let repository = LibraryControllerRouteRepository()
        let controller = LibraryControllerTestFactory.makeController(repository: repository)
        controller.start()
        await controller.refreshTask?.value
        controller.saveCompletedRoute(route, closeAfterSave: true)
        let save = controller.completedSaveTask
        #expect(await waitUntil { await repository.pendingSaveCount == 1 })
        controller.stop()
        let recorder = LibraryControllerUpdateRecorder(stream: controller.observe())
        recorder.start()
        controller.start()
        await controller.refreshTask?.value
        await repository.completeSave()
        await save?.value
        await controller.refreshTask?.value
        controller.stop()
        #expect(await waitUntil { recorder.isFinished })
        #expect(recorder.effects.isEmpty)
        #expect(controller.snapshot.savedRoutes.map(\.id) == [route.id])
        recorder.stop()
    }

    @Test("An accepted completed save survives release of the controller")
    func completedSaveSurvivesDeinit() async {
        let route = LibraryControllerTestRoutes.route(name: "Completed")
        let repository = LibraryControllerRouteRepository()
        var controller: RideNavigationLibraryController? = LibraryControllerTestFactory.makeController(
            repository: repository
        )
        weak var releasedController = controller
        controller?.saveCompletedRoute(route)
        let save = controller?.completedSaveTask
        #expect(await waitUntil { await repository.pendingSaveCount == 1 })
        controller = nil
        #expect(releasedController == nil)
        await repository.completeSave()
        await save?.value
        #expect(await repository.saveCancellationStates == [false])
        #expect(await repository.savedRoutes.map(\.id) == [route.id])
    }

    @Test("Changing the selected route rejects an older planned-save effect")
    func stalePlannedSaveDoesNotAdvanceNewSelection() async {
        let first = LibraryControllerTestRoutes.route(name: "First")
        let second = LibraryControllerTestRoutes.route(name: "Second")
        let repository = LibraryControllerRouteRepository()
        let controller = LibraryControllerTestFactory.makeController(repository: repository)
        let recorder = LibraryControllerUpdateRecorder(stream: controller.observe())
        recorder.start()
        controller.start()
        await controller.refreshTask?.value
        controller.selectImportedRoute(id: first.id)
        controller.savePlannedRoute(first)
        let save = controller.plannedSaveTask
        #expect(await waitUntil { await repository.pendingSaveCount == 1 })
        controller.selectImportedRoute(id: second.id)
        await repository.completeSave()
        await save?.value
        #expect(controller.selectedRouteID == second.id)
        #expect(controller.snapshot.persistence.status == .idle)
        controller.stop()
        #expect(await waitUntil { recorder.isFinished })
        #expect(recorder.effects.isEmpty)
        recorder.stop()
    }

    @Test("A new context queues its completed save without inheriting the old result", arguments: [false, true])
    func newContextQueuesSave(oldSaveFails: Bool) async throws {
        let first = LibraryControllerTestRoutes.route(name: "First completion")
        let second = LibraryControllerTestRoutes.route(name: "Second completion")
        let repository = LibraryControllerRouteRepository()
        let controller = LibraryControllerTestFactory.makeController(repository: repository)
        let recorder = LibraryControllerUpdateRecorder(stream: controller.observe())
        recorder.start()
        controller.start()
        await controller.refreshTask?.value
        controller.saveCompletedRoute(first, closeAfterSave: true)
        let oldSave = controller.completedSaveTask
        try #require(await waitUntil { await repository.pendingSaveCount == 1 })
        controller.resetPersistence()
        controller.saveCompletedRoute(second, closeAfterSave: true)
        let newSave = controller.completedSaveTask
        #expect(controller.snapshot.persistence.status == .saving)
        if oldSaveFails {
            await repository.failSave()
        } else {
            await repository.completeSave()
        }
        await oldSave?.value
        try #require(await waitUntil { await repository.pendingSaveCount == 1 })
        #expect(controller.snapshot.persistence.status == .saving)
        #expect(controller.snapshot.errorMessage == nil)
        await repository.completeSave()
        await newSave?.value
        await controller.refreshTask?.value
        controller.stop()
        #expect(await waitUntil { recorder.isFinished })
        #expect(recorder.effects == [.closeCompletedRoute(second.id)])
        #expect(controller.snapshot.persistence.status == .saved)
        let expectedIDs = oldSaveFails ? [second.id] : [first.id, second.id]
        #expect(await repository.savedRoutes.map(\.id) == expectedIDs)
        #expect(Set(controller.snapshot.savedRoutes.map(\.id)) == Set(expectedIDs))
        recorder.stop()
    }

    @Test("Releasing the controller preserves every already accepted completed write in its queue")
    func queuedCompletedSavesSurviveDeinit() async throws {
        let first = LibraryControllerTestRoutes.route(name: "First completion")
        let second = LibraryControllerTestRoutes.route(name: "Second completion")
        let repository = LibraryControllerRouteRepository()
        var controller: RideNavigationLibraryController? = LibraryControllerTestFactory.makeController(
            repository: repository
        )
        weak var releasedController = controller
        controller?.saveCompletedRoute(first)
        try #require(await waitUntil { await repository.pendingSaveCount == 1 })
        controller?.resetPersistence()
        controller?.saveCompletedRoute(second)
        let queuedSave = controller?.completedSaveTask
        controller = nil
        #expect(releasedController == nil)
        await repository.completeSave()
        try #require(await waitUntil { await repository.pendingSaveCount == 1 })
        await repository.completeSave()
        await queuedSave?.value
        #expect(await repository.savedRoutes.map(\.id) == [first.id, second.id])
        #expect(await repository.saveCancellationStates == [false, false])
    }
}
