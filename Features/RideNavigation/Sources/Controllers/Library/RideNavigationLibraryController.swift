import Foundation
import RideNavigationDomain

@MainActor
public final class RideNavigationLibraryController {
    var snapshot = RideNavigationLibrarySnapshot()
    let routeLibrary: RideNavigationRouteLibraryService
    let timing: RideNavigationTiming
    var continuation: AsyncStream<RideNavigationLibraryUpdate>.Continuation?
    var isStarted = false
    var lifecycleGeneration: UInt = 0
    var contextGeneration: UInt = 0
    var refreshGeneration: UInt = 0
    var saveGeneration: UInt = 0
    var selectedRouteID: UUID?
    var refreshTask: Task<Void, Never>?
    var plannedSaveTask: Task<Void, Never>?
    var completedSaveTask: Task<Void, Never>?
    var draftTask: Task<Void, Never>?
    var deletionTasks: [UUID: Task<Void, Never>] = [:]

    public init(routeLibrary: RideNavigationRouteLibraryService, timing: RideNavigationTiming) {
        self.routeLibrary = routeLibrary
        self.timing = timing
    }

    deinit {
        continuation?.finish()
        refreshTask?.cancel()
        plannedSaveTask?.cancel()
        draftTask?.cancel()
        deletionTasks.values.forEach { $0.cancel() }
        // An accepted completed-route write deliberately survives its presentation owner.
    }

    func observe() -> AsyncStream<RideNavigationLibraryUpdate> {
        continuation?.finish()
        let pair = AsyncStream<RideNavigationLibraryUpdate>.makeStream()
        continuation = pair.continuation
        publish()
        return pair.stream
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        lifecycleGeneration &+= 1
        refresh()
    }

    func stop() {
        isStarted = false
        lifecycleGeneration &+= 1
        invalidateRefresh()
        plannedSaveTask?.cancel()
        plannedSaveTask = nil
        draftTask?.cancel()
        deletionTasks.values.forEach { $0.cancel() }
        deletionTasks.removeAll()
        snapshot.persistence.cancelTransientSave()
        continuation?.finish()
        continuation = nil
    }

    func publish(effect: RideNavigationLibraryUpdate.Effect? = nil) {
        continuation?.yield(.init(snapshot: snapshot, contextGeneration: contextGeneration, effect: effect))
    }

    func selectImportedRoute(id: UUID) {
        resetPersistence()
        selectedRouteID = id
        snapshot.persistence.selectImportedRoute()
        publish()
    }

    func selectSavedRoute(id: UUID) {
        resetPersistence()
        selectedRouteID = id
        snapshot.persistence.selectSavedRoute()
        publish()
    }

    func resetPersistence() {
        contextGeneration &+= 1
        plannedSaveTask?.cancel()
        plannedSaveTask = nil
        selectedRouteID = nil
        snapshot.persistence.reset()
        snapshot.errorMessage = nil
        publish()
    }

    func requestCloseAfterSave() {
        snapshot.persistence.requestCloseAfterSave()
    }

    func clearPersistenceFailure() {
        snapshot.persistence.clearFailure()
        publish()
    }

    func clearError() {
        snapshot.errorMessage = nil
        publish()
    }

    func invalidateRefresh() {
        refreshGeneration &+= 1
        refreshTask?.cancel()
        refreshTask = nil
    }

    func refresh() {
        invalidateRefresh()
        guard isStarted else { return }
        let generation = refreshGeneration
        let lifecycle = lifecycleGeneration
        refreshTask = Task { [weak self, routeLibrary] in
            let routes = await routeLibrary.loadRoutes()
            guard !Task.isCancelled, let self, isStarted,
                  refreshGeneration == generation, lifecycleGeneration == lifecycle else { return }
            refreshTask = nil
            snapshot.savedRoutes = routes.filter { deletionTasks[$0.id] == nil }
            publish()
        }
    }
}
