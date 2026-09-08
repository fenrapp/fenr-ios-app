import Foundation
import RideNavigationDomain

@MainActor
extension RideNavigationViewModel {
    public func saveCompletedRoute(name: String) {
        errorText = nil
        activityController.saveCompletedRoute(name: name)
        render()
    }

    public func saveCompletedRouteAndClose(name: String) {
        guard let completedRecording = activityController.snapshot.completedRecording else {
            discardActivity()
            return
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmed.isEmpty ? completedRecording.name : trimmed
        if library.snapshot.persistence.status == .saved,
           resolvedName == completedRecording.name {
            discardActivity()
            return
        }
        library.requestCloseAfterSave()
        saveCompletedRoute(name: resolvedName)
    }

    public func retryCompletedRouteSave(name: String? = nil) {
        guard let completed = activityController.snapshot.completedRecording,
              case .failed = library.snapshot.persistence.status else { return }
        activityController.saveCompletedRoute(name: name ?? completed.name)
        render()
    }

    public func discardUnsavedCompletedRoute() {
        guard case .failed = library.snapshot.persistence.status else { return }
        library.clearPersistenceFailure()
        discardActivity()
    }

    public func exportCompletedRoute() {
        guard canExportCompletedRoute,
              let route = activityController.snapshot.completedRecording
                ?? planningController.snapshot.selectedRoute ?? roadRouteForExport else {
            errorText = String(localized: .rideNavigationNoRouteToExport)
            render()
            return
        }
        library.exportRoute(route)
        render()
    }

    public func clearExportRequest() {
        library.clearExportRequest()
        render()
    }

    public func shareSavedRoute(id: UUID) {
        errorText = nil
        library.clearError()
        library.shareSavedRoute(id: id)
        render()
    }

    public func clearShareRequest() {
        library.clearShareRequest()
        render()
    }

    public func deleteSavedRoute(id: UUID) {
        cancelSavedRouteLoad()
        guard library.snapshot.savedRoutes.contains(where: { $0.id == id }) else { return }
        if planningController.snapshot.selectedRoute?.id == id {
            planningController.resetPlan()
            activityController.resetForPreview()
            library.resetPersistence()
        }
        errorText = nil
        library.clearError()
        library.deleteSavedRoute(id: id)
        render()
    }

    public func openIncomingMapLink(_ url: URL) {
        cancelSavedRouteLoad()
        planningController.resolveExternalLink(url)
    }

    public func keepRidingWithIncomingDestination() {
        showsIncomingDestinationPrompt = false
        openIncomingDestinationAfterSummary = true
        render()
    }

    public func endRideAndOpenIncomingDestination() {
        showsIncomingDestinationPrompt = false
        guard let destination = planningController.snapshot.pendingExternalDestination else {
            render()
            return
        }
        if activityController.snapshot.activity == .recording || activityController.snapshot.activity == .paused {
            openIncomingDestinationAfterSummary = true
            finishActivity()
            return
        }
        activityController.stopNavigationWithoutSummary()
        planningController.consumePendingDestination()
        previewExternalDestination(destination)
    }

    public func importGPX(from url: URL) {
        cancelSavedRouteLoad()
        do {
            let routes = try library.importGPX(from: url)
            guard let route = routes.first else { return }
            planningController.selectTrailRoute(route)
            activityController.resetForPreview()
            library.selectImportedRoute(id: route.id)
            activityController.resetRoadStepGuidance()
            screen = .map
            mapDisplayStyle = .map
            cameraMode = .automatic
            errorText = routes.count > 1
                ? String(localized: .rideNavigationGPXMultipleTracks(trackCount: routes.count))
                : nil
            render()
            prepareTrailPreview()
        } catch {
            errorText = String(localized: .rideNavigationGPXReadError)
            render()
        }
    }

    public func toggleRouteDirection() {
        guard planningController.snapshot.selectedRoute != nil else { return }
        planningController.setDirection(planningController.snapshot.selectedDirection == .forward ? .reverse : .forward)
        activityController.resetForPreview()
        cameraMode = .automatic
        render()
        prepareTrailPreview()
    }

    public func startPreviewedRoute() {
        guard planningController.snapshot.selectedRoute != nil
                || planningController.snapshot.roadRoute != nil else { return }
        if planningController.snapshot.selectedRoute != nil {
            startSelectedTrailRoute()
            return
        }
        let update = activityController.beginRoadNavigation()
        receiveActivityUpdate(update)
    }

    func defaultRouteName(at date: Date) -> String {
        String(localized: .rideNavigationDefaultRideName(date.formatted(date: .abbreviated, time: .shortened)))
    }

    func previewExternalDestination(_ destination: NavigationPlace) {
        guard let origin = locationSnapshot.coordinate else {
            planningController.holdExternalDestination(destination)
            errorText = String(localized: .rideNavigationCurrentLocationRequired)
            render()
            return
        }
        screen = .map
        mapDisplayStyle = .map
        planningController.prepareExternalDestination(destination)
        library.resetPersistence()
        activityController.resetForPreview()
        errorText = nil
        library.clearError()
        calculateRoadPreview(from: origin, to: destination, showsSearchLoading: false)
    }
}
