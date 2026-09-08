import Foundation

@MainActor
extension RideNavigationViewModel {
    func startPlanningObservation(lifecycle: UInt) {
        planningObservationTask?.cancel()
        let stream = planningController.observe()
        planningObservationTask = Task { [weak self] in
            for await update in stream {
                guard !Task.isCancelled, let self, isStarted,
                      lifecycleGeneration == lifecycle else { return }
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
            activityController.resetForPreview()
            screen = .map
            mapDisplayStyle = .map
            showUpdatedRoadPreview()
        case .previewUpdated:
            showUpdatedRoadPreview()
        case .rerouteReady:
            activityController.resetRoadStepGuidance()
            errorText = nil
            library.clearError()
            activityController.announce(String(localized: .rideNavigationAnnouncementRouteUpdated))
        case .approachReady:
            let activityUpdate = activityController.beginRoadNavigation(isApproach: true)
            receiveActivityUpdate(activityUpdate)
        case .trailExitReady:
            if activityController.snapshot.activity == .following,
               let exit = planningController.snapshot.trailExitPreview {
                cameraMode = .overview(
                    activityController.snapshot.trailOverviewCoordinates
                        + dependencies.mapPresentationMapper.coordinates(exit.route.points)
                )
            }
        case .externalDestinationResolved:
            receiveIncomingDestination()
        case nil:
            break
        }
        render()
    }

    private func showUpdatedRoadPreview() {
        activityController.resetRoadStepGuidance()
        cameraMode = .overview(
            dependencies.mapPresentationMapper.coordinates(planningController.snapshot.roadRoute?.points ?? [])
        )
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
