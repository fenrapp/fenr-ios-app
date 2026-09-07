import Foundation
import RideNavigationDomain

@MainActor
extension RideNavigationLibraryController {
    func savePlannedRoute(_ route: RideRoute) {
        guard !snapshot.persistence.status.isSaving, selectedRouteID == route.id else { return }
        plannedSaveTask?.cancel()
        invalidateRefresh()
        let context = contextGeneration
        let lifecycle = lifecycleGeneration
        snapshot.persistence.beginPlannedRouteSave()
        snapshot.errorMessage = nil
        publish()
        plannedSaveTask = Task { [weak self, routeLibrary] in
            do {
                try await routeLibrary.save(route)
                guard !Task.isCancelled, let self, isStarted,
                      contextGeneration == context, lifecycleGeneration == lifecycle,
                      selectedRouteID == route.id else { return }
                plannedSaveTask = nil
                includeSavedRoute(route)
                snapshot.persistence.completePlannedRouteSave()
                publish(effect: .plannedRouteReady(route.id))
                refresh()
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, let self, isStarted,
                      contextGeneration == context, lifecycleGeneration == lifecycle else { return }
                plannedSaveTask = nil
                snapshot.persistence.fail(String(localized: .rideNavigationImportedGPXSaveRetry))
                snapshot.errorMessage = String(localized: .rideNavigationImportedGPXSaveError)
                publish()
                refresh()
            }
        }
    }

    func saveCompletedRoute(_ route: RideRoute, closeAfterSave: Bool = false) {
        guard !snapshot.persistence.status.isSaving else { return }
        let previous = completedSaveTask
        invalidateRefresh()
        saveGeneration &+= 1
        let generation = saveGeneration
        let context = contextGeneration
        let lifecycle = lifecycleGeneration
        snapshot.persistence.beginCompletedRouteSave()
        if closeAfterSave { snapshot.persistence.requestCloseAfterSave() }
        snapshot.errorMessage = nil
        publish()
        // Capture the immutable write inputs, never the controller across suspension.
        completedSaveTask = Task { [weak self, routeLibrary] in
            // Every accepted context owns a write; replacing its UI must not drop it.
            await previous?.value
            do {
                try await routeLibrary.save(route)
                guard let self, saveGeneration == generation else { return }
                completedSaveTask = nil
                includeSavedRoute(route)
                if contextGeneration == context {
                    let shouldClose = snapshot.persistence.completeCompletedRouteSave()
                    let canClose = shouldClose && isStarted && lifecycleGeneration == lifecycle
                    publish(effect: canClose ? .closeCompletedRoute(route.id) : nil)
                } else {
                    publish()
                }
                refresh()
            } catch {
                guard let self, saveGeneration == generation else { return }
                completedSaveTask = nil
                guard contextGeneration == context else { return }
                snapshot.persistence.fail(String(localized: .rideNavigationRecordedRouteSaveError))
                publish()
                refresh()
            }
        }
    }

    func includeSavedRoute(_ route: RideRoute) {
        guard deletionTasks[route.id] == nil else { return }
        snapshot.savedRoutes.removeAll { $0.id == route.id }
        snapshot.savedRoutes.insert(route, at: 0)
    }

    func deleteSavedRoute(id: UUID) {
        guard snapshot.savedRoutes.contains(where: { $0.id == id }), deletionTasks[id] == nil else { return }
        invalidateRefresh()
        let lifecycle = lifecycleGeneration
        snapshot.savedRoutes.removeAll { $0.id == id }
        snapshot.errorMessage = nil
        deletionTasks[id] = Task { [weak self, routeLibrary] in
            do {
                try await routeLibrary.delete(id: id)
                guard !Task.isCancelled, let self, isStarted, lifecycleGeneration == lifecycle else { return }
                deletionTasks[id] = nil
                refresh()
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, let self, isStarted, lifecycleGeneration == lifecycle else { return }
                deletionTasks[id] = nil
                snapshot.errorMessage = String(localized: .rideNavigationRouteDeleteError)
                publish()
                refresh()
            }
        }
        publish()
    }

    func scheduleDraft(_ route: RideRoute) {
        replaceDraft(route, debounce: true)
    }

    func clearDraft() {
        replaceDraft(nil, debounce: false)
    }

    private func replaceDraft(_ route: RideRoute?, debounce: Bool) {
        let previous = draftTask
        previous?.cancel()
        draftTask = Task { [routeLibrary, timing] in
            // A non-cooperative write must finish before a newer draft or clear begins.
            await previous?.value
            do {
                try Task.checkCancellation()
                if debounce { try await timing.sleep(.seconds(2)) }
                try Task.checkCancellation()
                try await routeLibrary.saveDraft(route)
            } catch {
                return
            }
        }
    }
}
