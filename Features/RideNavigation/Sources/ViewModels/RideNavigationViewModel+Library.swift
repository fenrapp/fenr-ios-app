import Foundation
import RideNavigationDomain

@MainActor
extension RideNavigationViewModel {
    public func saveCompletedRoute(name: String) {
        guard let completedRecording else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let route = completedRecording.renamed(
            trimmed.isEmpty ? completedRecording.name : trimmed,
            at: now()
        )
        let replacedRoute = savedRoutes.first { $0.id == route.id }
        publishSavedRoute(route)
        let generation = operations.begin(.routeSave)
        let lifecycle = operations.lifecycleGeneration
        let repository = repository
        routeSaveTask = Task { [weak self] in
            do {
                try await repository.save(route)
                try Task.checkCancellation()
                let routes = await repository.loadRoutes()
                try Task.checkCancellation()
                guard let self,
                      operations.isCurrent(.routeSave, generation: generation, lifecycle: lifecycle),
                      isStarted else { return }
                savedRoutes = routes
                if screen == .summary, self.completedRecording?.id == route.id {
                    self.completedRecording = route
                    errorText = nil
                }
                render()
            } catch is CancellationError {
                return
            } catch {
                guard let self,
                      operations.isCurrent(.routeSave, generation: generation, lifecycle: lifecycle),
                      isStarted else { return }
                savedRoutes.removeAll { $0.id == route.id }
                if let replacedRoute {
                    savedRoutes.insert(replacedRoute, at: .zero)
                }
                errorText = "The route could not be saved."
                render()
            }
        }
    }

    public func saveCompletedRouteAndClose(name: String) {
        guard completedRecording != nil else {
            discardActivity()
            return
        }
        saveCompletedRoute(name: name)
        discardActivity()
    }

    func publishSavedRoute(_ route: RideRoute) {
        savedRoutes.removeAll { $0.id == route.id }
        savedRoutes.insert(route, at: .zero)
        completedRecording = route
        errorText = nil
        render()
    }

    public func exportCompletedRoute() {
        guard let route = completedRecording ?? selectedRoute ?? roadRouteForExport else {
            errorText = "There is no route available to export."
            render()
            return
        }
        do {
            exportRequest = GPXExportRequest(
                filename: sanitizedFilename(route.name) + ".gpx",
                data: try exporter.export(route)
            )
        } catch {
            errorText = "The GPX file could not be created."
            render()
        }
    }

    public func clearExportRequest() {
        exportRequest = nil
    }

    public func shareSavedRoute(id: UUID) {
        guard let route = savedRoutes.first(where: { $0.id == id }) else { return }
        do {
            shareRequest = GPXExportRequest(
                filename: sanitizedFilename(route.name) + ".gpx",
                data: try exporter.export(route)
            )
            errorText = nil
            render()
        } catch {
            errorText = "The GPX file could not be created."
            render()
        }
    }

    public func clearShareRequest() {
        shareRequest = nil
    }

    public func deleteSavedRoute(id: UUID) {
        guard savedRoutes.contains(where: { $0.id == id }) else { return }
        savedRoutes.removeAll { $0.id == id }
        if selectedRoute?.id == id {
            selectedRoute = nil
        }
        errorText = nil
        render()

        let repository = repository
        routeDeletionTasks[id] = Task { [weak self] in
            do {
                try await repository.delete(id: id)
                try Task.checkCancellation()
                let routes = await repository.loadRoutes()
                try Task.checkCancellation()
                self?.receiveRouteDeletion(routes, id: id, errorText: nil)
            } catch is CancellationError {
                return
            } catch {
                let routes = await repository.loadRoutes()
                guard !Task.isCancelled else { return }
                self?.receiveRouteDeletion(
                    routes,
                    id: id,
                    errorText: "The route could not be deleted."
                )
            }
        }
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
                errorText = "This map link does not contain a destination FENR can open."
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
        let gainedAccess = url.startAccessingSecurityScopedResource()
        defer { if gainedAccess { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            let fallbackName = url.deletingPathExtension().lastPathComponent
            let routes = try importer.importRoutes(from: data, fallbackName: fallbackName)
            guard let route = routes.first else { return }
            selectedRoute = route
            selectedDirection = .forward
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
            cameraMode = .overview(mapMapper.coordinates(route.points.map(\.coordinate)))
            errorText = routes.count > 1
                ? "This GPX contains \(routes.count) tracks. Showing the first track."
                : nil
            render()
        } catch {
            errorText = "This GPX file could not be read."
            render()
        }
    }

    public func openSavedRoute(id: UUID) {
        guard let route = savedRoutes.first(where: { $0.id == id }) else { return }
        selectedRoute = route
        selectedDirection = .forward
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
        cameraMode = .overview(mapMapper.coordinates(route.points.map(\.coordinate)))
        errorText = nil
        render()
    }

    public func toggleRouteDirection() {
        guard let selectedRoute else { return }
        selectedDirection = selectedDirection == .forward ? .reverse : .forward
        trailProgress = nil
        let oriented = selectedDirection == .forward ? selectedRoute : selectedRoute.reversed
        cameraMode = .overview(mapMapper.coordinates(oriented.points.map(\.coordinate)))
        render()
    }

    public func startPreviewedRoute() {
        guard selectedRoute != nil || roadRoute != nil else { return }
        if let route = orientedRoute,
           let origin = locationSnapshot.coordinate,
           let start = route.points.first?.coordinate,
           RideRouteGeometry.distanceMeters(from: origin, to: start) > Constants.approachDistanceMeters {
            startApproachRoute(from: origin, to: start)
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
        announce(activity == .following ? "Enduro navigation started" : "Road navigation started")
    }

    func receiveLoadedRoutes(_ routes: [RideRoute]) {
        savedRoutes = routes
        render()
    }

    func receiveRouteDeletion(
        _ routes: [RideRoute],
        id: UUID,
        errorText: String?
    ) {
        routeDeletionTasks[id] = nil
        let pendingDeletionIDs = Set(routeDeletionTasks.keys)
        savedRoutes = routes.filter { !pendingDeletionIDs.contains($0.id) }
        self.errorText = errorText
        render()
    }

    func defaultRouteName(at date: Date) -> String {
        "Ride \(date.formatted(date: .abbreviated, time: .shortened))"
    }

    func sanitizedFilename(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let sanitized = value.unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : "-" }
        let filename = String(sanitized).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return filename.isEmpty ? "Ride" : filename
    }
}
