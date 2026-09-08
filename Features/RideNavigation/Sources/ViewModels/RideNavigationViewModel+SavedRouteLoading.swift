import Foundation
import RideNavigationDomain

@MainActor
extension RideNavigationViewModel {
    public func openSavedRoute(id: UUID) {
        guard let requested = library.snapshot.savedRoutes.first(where: { $0.id == id }) else { return }
        cancelSavedRouteLoad()
        planningController.resetPlan()
        activityController.resetForPreview()
        library.selectSavedRoute(id: id)
        let generation = savedRouteLoadingGeneration
        let lifecycle = lifecycleGeneration
        let planningContext = planningController.contextGeneration
        let libraryContext = library.contextGeneration
        let routeLibrary = library.routeLibrary
        savedRouteLoadingTask = Task { [weak self] in
            defer { self?.completeSavedRouteLoad(generation: generation) }
            do {
                guard let route = try await routeLibrary.loadRoute(id: id) else {
                    throw CocoaError(.fileReadNoSuchFile)
                }
                guard !Task.isCancelled, let self, isStarted, savedRouteLoadingGeneration == generation,
                      lifecycleGeneration == lifecycle, planningController.contextGeneration == planningContext,
                      library.contextGeneration == libraryContext,
                      library.snapshot.savedRoutes.first(where: { $0.id == id }) == requested else { return }
                presentSavedRoute(route)
            } catch {
                guard !Task.isCancelled, let self, isStarted, savedRouteLoadingGeneration == generation,
                      lifecycleGeneration == lifecycle, planningController.contextGeneration == planningContext,
                      library.contextGeneration == libraryContext,
                      library.snapshot.savedRoutes.first(where: { $0.id == id }) == requested else { return }
                errorText = String(localized: .rideNavigationSavedRouteReadError)
                render()
            }
        }
    }

    private func completeSavedRouteLoad(generation: UInt) {
        guard savedRouteLoadingGeneration == generation else { return }
        savedRouteLoadingTask = nil
    }

    func cancelSavedRouteLoad() {
        savedRouteLoadingGeneration &+= 1
        savedRouteLoadingTask?.cancel()
        savedRouteLoadingTask = nil
    }

    private func presentSavedRoute(_ route: RideRoute) {
        planningController.selectTrailRoute(route)
        activityController.resetRoadStepGuidance()
        screen = .map
        mapDisplayStyle = .map
        cameraMode = .automatic
        errorText = nil
        library.clearError()
        render()
        prepareTrailPreview()
    }
}
