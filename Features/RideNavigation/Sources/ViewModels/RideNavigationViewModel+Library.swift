import Foundation
import RideNavigationDomain

@MainActor
extension RideNavigationViewModel {
    public func saveCompletedRoute(name: String) {
        guard let completedRecording, !library.snapshot.persistence.status.isSaving else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let route = completedRecording.renamed(
            trimmed.isEmpty ? completedRecording.name : trimmed,
            at: now()
        )
        beginCompletedRouteSave(route)
    }

    func beginCompletedRouteSave(_ route: RideRoute) {
        completedRecording = route
        errorText = nil
        library.clearError()
        library.saveCompletedRoute(route)
        render()
    }

    public func saveCompletedRouteAndClose(name: String) {
        guard let completedRecording else {
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
        guard let completedRecording,
              case .failed = library.snapshot.persistence.status else { return }
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let route = trimmed.isEmpty
            ? completedRecording
            : completedRecording.renamed(trimmed, at: now())
        beginCompletedRouteSave(route)
    }

    public func discardUnsavedCompletedRoute() {
        guard case .failed = library.snapshot.persistence.status else { return }
        library.clearPersistenceFailure()
        discardActivity()
    }

    public func exportCompletedRoute() {
        guard canExportCompletedRoute, let route = completedRecording ?? selectedRoute ?? roadRouteForExport else {
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
        guard library.snapshot.savedRoutes.contains(where: { $0.id == id }) else { return }
        if selectedRoute?.id == id {
            selectedRoute = nil
            trailMap.reset()
            library.resetPersistence()
        }
        errorText = nil
        library.clearError()
        library.deleteSavedRoute(id: id)
        render()
    }

    public func openIncomingMapLink(_ url: URL) {
        let generation = operations.begin(.externalLink)
        let lifecycle = operations.lifecycleGeneration
        let resolver = externalMapLinkResolver
        externalLinkTask = Task { [weak self] in
            do {
                let destination = try await resolver.destination(from: url)
                try Task.checkCancellation()
                guard let self,
                      operations.isCurrent(.externalLink, generation: generation, lifecycle: lifecycle),
                      isStarted else { return }
                pendingExternalDestination = destination
                if hasActiveSession {
                    showsIncomingDestinationPrompt = true
                    render()
                } else {
                    pendingExternalDestination = nil
                    previewExternalDestination(destination)
                }
            } catch is CancellationError {
                return
            } catch {
                guard let self,
                      operations.isCurrent(.externalLink, generation: generation, lifecycle: lifecycle),
                      isStarted else { return }
                errorText = String(localized: .rideNavigationMapLinkNoDestination)
                render()
            }
        }
    }

    public func keepRidingWithIncomingDestination() {
        showsIncomingDestinationPrompt = false
        openIncomingDestinationAfterSummary = true
        render()
    }

    public func endRideAndOpenIncomingDestination() {
        showsIncomingDestinationPrompt = false
        guard let destination = pendingExternalDestination else {
            render()
            return
        }
        if activity == .recording || activity == .paused {
            openIncomingDestinationAfterSummary = true
            finishActivity(reason: .rideRecorded)
            return
        }
        stopNavigationWithoutSummary()
        pendingExternalDestination = nil
        previewExternalDestination(destination)
    }

    public func importGPX(from url: URL) {
        do {
            let routes = try library.importGPX(from: url)
            guard let route = routes.first else { return }
            selectedRoute = route
            selectedDirection = .forward
            trailMap.reset()
            library.selectImportedRoute(id: route.id)
            trailGuidance.reset()
            trailProgress = nil
            roadRoute = nil
            roadRoutes = []
            roadNavigationPurpose = nil
            trailExitPreview = nil
            selectedRoadRouteIndex = 0
            resetRoadStepGuidance()
            screen = .map
            activity = .preview
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

    public func openSavedRoute(id: UUID) {
        guard let route = library.snapshot.savedRoutes.first(where: { $0.id == id }) else { return }
        selectedRoute = route
        selectedDirection = .forward
        trailMap.reset()
        library.selectSavedRoute(id: route.id)
        trailGuidance.reset()
        trailProgress = nil
        roadRoute = nil
        roadRoutes = []
        roadNavigationPurpose = nil
        trailExitPreview = nil
        selectedRoadRouteIndex = 0
        resetRoadStepGuidance()
        screen = .map
        activity = .preview
        mapDisplayStyle = .map
        cameraMode = .automatic
        errorText = nil
        library.clearError()
        render()
        prepareTrailPreview()
    }

    public func toggleRouteDirection() {
        guard selectedRoute != nil else { return }
        selectedDirection = selectedDirection == .forward ? .reverse : .forward
        trailMap.reset()
        trailProgress = nil
        trailGuidance.reset()
        cameraMode = .automatic
        render()
        prepareTrailPreview()
    }

    public func startPreviewedRoute() {
        guard selectedRoute != nil || roadRoute != nil else { return }
        if selectedRoute != nil {
            startSelectedTrailRoute()
            return
        }
        let date = now()
        startBreadcrumb(at: date)
        activityStartedAt = date
        activity = roadRoute == nil ? .following : .navigating
        if activity == .navigating, roadNavigationPurpose == nil {
            roadNavigationPurpose = .destination
        }
        applyPreferredMapStyleForActiveNavigation()
        cameraMode = followCamera
        screen = .map
        startClock()
        render()
        announce(String(localized: activity == .following
            ? .rideNavigationAnnouncementEnduroStarted
            : .rideNavigationAnnouncementRoadStarted))
    }

    func defaultRouteName(at date: Date) -> String {
        String(localized: .rideNavigationDefaultRideName(date.formatted(date: .abbreviated, time: .shortened)))
    }

    func previewExternalDestination(_ destination: NavigationPlace) {
        guard let origin = locationSnapshot.coordinate else {
            pendingExternalDestination = destination
            errorText = String(localized: .rideNavigationCurrentLocationRequired)
            render()
            return
        }
        stopClock()
        screen = .map
        activity = .preview
        mapDisplayStyle = .map
        selectedRoute = nil
        library.resetPersistence()
        trailMap.reset()
        trailProgress = nil
        trailExitPreview = nil
        roadNavigationPurpose = .destination
        selectedDestination = destination
        errorText = nil
        library.clearError()
        calculateRoadPreview(from: origin, to: destination, showsSearchLoading: false)
    }
}
