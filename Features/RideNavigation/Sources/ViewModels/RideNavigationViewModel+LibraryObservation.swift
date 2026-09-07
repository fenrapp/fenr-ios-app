import Foundation

@MainActor
extension RideNavigationViewModel {
    func startLibraryObservation(lifecycle: UInt) {
        libraryObservationTask?.cancel()
        // Attach synchronously so commands cannot emit before this subscription exists.
        let stream = library.observe()
        libraryObservationTask = Task { [weak self] in
            for await update in stream {
                guard !Task.isCancelled, let self, isStarted,
                      operations.lifecycleGeneration == lifecycle else { return }
                guard update.contextGeneration == library.contextGeneration else { continue }
                switch update.effect {
                case let .plannedRouteReady(id) where planningController.snapshot.selectedRoute?.id == id:
                    startSelectedTrailRoute()
                case let .closeCompletedRoute(id) where screen == .summary && completedRecording?.id == id:
                    discardActivity()
                default:
                    render()
                }
            }
        }
    }
}
