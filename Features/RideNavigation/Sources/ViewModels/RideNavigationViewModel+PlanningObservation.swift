import Foundation

@MainActor
extension RideNavigationViewModel {
    func startPlanningObservation(lifecycle: UInt) {
        planningObservationTask?.cancel()
        let stream = planningController.observe()
        planningObservationTask = Task { [weak self] in
            for await update in stream {
                guard !Task.isCancelled, let self, isStarted,
                      operations.lifecycleGeneration == lifecycle else { return }
                receivePlanningUpdate(update)
            }
        }
    }

    func receivePlanningUpdate(_ update: RideNavigationPlanningUpdate) {
        guard isStarted, planningController.accepts(update) else { return }
        switch update.effect {
        case .previewReady:
            planningController.acknowledgePreviewPresentation(update)
            library.resetPersistence()
            trailMap.reset()
            trailProgress = nil
            screen = .map
            activity = .preview
            mapDisplayStyle = .map
            showUpdatedRoadPreview()
        case .previewUpdated:
            showUpdatedRoadPreview()
        case .rerouteReady:
            resetRoadStepGuidance()
            errorText = nil
            library.clearError()
            announce(String(localized: .rideNavigationAnnouncementRouteUpdated))
        case .approachReady:
            resetRoadStepGuidance()
            let date = now()
            startBreadcrumb(at: date)
            activityStartedAt = date
            activity = .navigating
            applyPreferredMapStyleForActiveNavigation()
            cameraMode = followCamera
            startClock()
            errorText = nil
            library.clearError()
            announce(String(localized: .rideNavigationAnnouncementTrailApproachStarted))
        case .trailExitReady:
            if activity == .following, let exit = planningController.snapshot.trailExitPreview {
                cameraMode = .overview(trailMap.overviewCoordinates + mapMapper.coordinates(exit.route.points))
            }
        case .externalDestinationResolved:
            receiveIncomingDestination()
        case nil:
            break
        }
        render()
    }

    private func showUpdatedRoadPreview() {
        resetRoadStepGuidance()
        cameraMode = .overview(mapMapper.coordinates(planningController.snapshot.roadRoute?.points ?? []))
        errorText = nil
        library.clearError()
    }

    private func receiveIncomingDestination() {
        guard let destination = planningController.snapshot.pendingExternalDestination else { return }
        if hasActiveSession {
            showsIncomingDestinationPrompt = true
        } else {
            planningController.consumePendingDestination()
            previewExternalDestination(destination)
        }
    }
}
