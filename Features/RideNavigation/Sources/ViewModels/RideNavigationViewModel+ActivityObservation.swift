import Foundation

@MainActor
extension RideNavigationViewModel {
    func startActivityObservation(lifecycle: UInt) {
        activityObservationTask?.cancel()
        let stream = activityController.observe()
        activityObservationTask = Task { [weak self] in
            for await update in stream {
                guard !Task.isCancelled, let self, isStarted, lifecycleGeneration == lifecycle else { return }
                receiveActivityUpdate(update)
            }
        }
    }

    func receiveActivityUpdate(_ update: RideNavigationActivityUpdate) {
        guard isStarted, activityController.accepts(update) else { return }
        activityController.acknowledgeEffect(update)
        switch update.effect {
        case .showActiveMap:
            screen = .map
            if activityController.snapshot.activity == .recording {
                mapDisplayStyle = .map
            } else {
                applyPreferredMapStyleForActiveNavigation()
            }
            cameraMode = followCamera
            errorText = nil
            synchronizePresentationObservations()
        case .showTrailOverview:
            cameraMode = .overview(update.snapshot.trailOverviewCoordinates)
        case let .completed(context):
            if presentationMode == .mini, context.completion.reason.isAutomaticArrival {
                frozenMiniMapScene = makeMiniMapScene(
                    activity: context.activity, planning: context.planning, location: context.location
                )
                miniCompletionTitle = context.completion.reason.title
                stopLocationObservation()
            }
            screen = .summary
            mapDisplayStyle = .map
            synchronizePresentationObservations()
        case nil:
            break
        }
        render()
    }
}
