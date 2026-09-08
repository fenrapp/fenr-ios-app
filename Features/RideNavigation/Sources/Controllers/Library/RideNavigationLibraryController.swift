import Foundation
import Observation
import RideNavigationDomain

@MainActor
@Observable
public final class RideNavigationLibraryController {
    var snapshot = RideNavigationLibrarySnapshot()
    let routeLibrary: RideNavigationRouteLibraryService
    let timing: RideNavigationTiming
    @ObservationIgnored var continuation: AsyncStream<RideNavigationLibraryUpdate>.Continuation?
    @ObservationIgnored var isStarted = false
    @ObservationIgnored var lifecycleGeneration: UInt = 0
    @ObservationIgnored var contextGeneration: UInt = 0
    @ObservationIgnored var refreshGeneration: UInt = 0
    @ObservationIgnored var saveGeneration: UInt = 0
    @ObservationIgnored var selectedRouteID: UUID?
    @ObservationIgnored var refreshTask: Task<Void, Never>?
    @ObservationIgnored var plannedSaveTask: Task<Void, Never>?
    @ObservationIgnored var completedSaveTask: Task<Void, Never>?
    @ObservationIgnored var shareTask: Task<Void, Never>?
    @ObservationIgnored var shareGeneration: UInt = 0
    @ObservationIgnored var sharingRouteID: UUID?
    @ObservationIgnored var draftTask: Task<Void, Never>?
    @ObservationIgnored var deletionTasks: [UUID: Task<Void, Never>] = [:]

    public init(routeLibrary: RideNavigationRouteLibraryService, timing: RideNavigationTiming) {
        self.routeLibrary = routeLibrary
        self.timing = timing
    }

    deinit {
        continuation?.finish()
        refreshTask?.cancel()
        shareTask?.cancel()
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
        cancelShare()
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
        cancelShare()
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
            let routes = await routeLibrary.loadRouteSummaries()
            guard !Task.isCancelled, let self, isStarted,
                  refreshGeneration == generation, lifecycleGeneration == lifecycle else { return }
            refreshTask = nil
            snapshot.savedRoutes = routes.filter { deletionTasks[$0.id] == nil }
            publish()
        }
    }
}
