@testable import RideNavigation
import Testing
import TestSupport

@MainActor
struct RideNavigationLibraryDraftTests {
    @Test("Clearing a draft waits for an older non-cooperative save before removing it")
    func clearWaitsForPendingWrite() async {
        let route = LibraryControllerTestRoutes.route(name: "Draft")
        let repository = LibraryControllerRouteRepository()
        let controller = LibraryControllerTestFactory.makeController(repository: repository)
        await repository.blockDrafts()
        controller.scheduleDraft(route)
        #expect(await waitUntil { await repository.pendingDraftCount == 1 })
        let original = controller.draftTask
        controller.clearDraft()
        let clear = controller.draftTask
        await repository.unblockDrafts()
        await repository.completeDraft()
        await original?.value
        await clear?.value
        #expect(await repository.savedDraftIDs == [route.id, nil])
        #expect(await repository.loadDraft() == nil)
        controller.stop()
    }

    @Test("A replacement draft finishes after the old write even across an intervening clear")
    func newestDraftWinsOverSuspendedSaveAndClear() async {
        let first = LibraryControllerTestRoutes.route(name: "First draft")
        let newest = LibraryControllerTestRoutes.route(name: "Latest draft")
        let repository = LibraryControllerRouteRepository()
        let controller = LibraryControllerTestFactory.makeController(repository: repository)
        await repository.blockDrafts()
        controller.scheduleDraft(first)
        #expect(await waitUntil { await repository.pendingDraftCount == 1 })
        controller.clearDraft()
        controller.scheduleDraft(newest)
        let latest = controller.draftTask
        await repository.unblockDrafts()
        await repository.completeDraft()
        await latest?.value
        #expect(await repository.savedDraftIDs == [first.id, newest.id])
        #expect(await repository.loadDraft()?.id == newest.id)
        controller.stop()
    }
}
