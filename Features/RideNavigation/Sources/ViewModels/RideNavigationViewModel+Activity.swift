import Foundation
import RideNavigationDomain

@MainActor
extension RideNavigationViewModel {
    public func startRecording() {
        let date = now()
        recorder.start(at: date, name: defaultRouteName(at: date))
        completedRecording = nil
        activityStartedAt = date
        screen = .map
        activity = .recording
        mapDisplayStyle = .map
        cameraMode = followCamera
        startClock()
        render()
        announce("Recording started")
    }

    public func toggleRecordingPause() {
        let date = now()
        switch activity {
        case .recording:
            recorder.pause(at: date)
            activity = .paused
            scheduleDraftSave()
            announce("Recording paused")
        case .paused:
            recorder.resume(at: date)
            activity = .recording
            announce("Recording resumed")
        default:
            return
        }
        render()
    }

    public func finishActivity() {
        let reason: CompletionReason
        switch activity {
        case .recording, .paused:
            reason = .rideRecorded
        case .following:
            reason = .trailEnded
        case .navigating where roadNavigationPurpose == .trailExit:
            reason = .exitNavigationEnded
        case .navigating:
            reason = .navigationEnded
        case .preview:
            return
        }
        finishActivity(reason: reason)
    }

    func finishActivity(reason: CompletionReason) {
        routeTask?.cancel()
        routeTask = nil
        trailExitTask?.cancel()
        trailExitTask = nil
        let date = now()
        let finishedActivity = activity
        let keepsMiniCompletion = presentationMode == .mini && reason.isAutomaticArrival
        if keepsMiniCompletion {
            frozenMiniMapScene = makeMiniMapScene()
            miniCompletionTitle = reason.title
        }
        let completedTrailRouteToSave = prepareCompletionSummary(
            reason: reason,
            finishedActivity: finishedActivity,
            at: date
        )
        summaryTitle = reason.title
        if finishedActivity == .navigating {
            _ = breadcrumbRecorder.finish(at: date)
        }
        activityStartedAt = nil
        activity = .preview
        mapDisplayStyle = .map
        isRerouting = false
        isCalculatingRoadRoutes = false
        isFindingTrailExit = false
        screen = .summary
        stopClock()
        synchronizePresentationObservations()
        render()
        if keepsMiniCompletion {
            locationObservationTask?.cancel()
            locationObservationTask = nil
        }
        if reason.emitsSuccessFeedback {
            replaceFeedbackTask { [guidance] in await guidance.notifySuccess() }
        }
        if let completedTrailRouteToSave {
            beginCompletedRouteSave(completedTrailRouteToSave)
        }
    }

    private func prepareCompletionSummary(
        reason: CompletionReason,
        finishedActivity: RideNavigationViewState.Activity,
        at date: Date
    ) -> RideRoute? {
        if reason == .rideRecorded {
            completedRecording = recorder.finish(at: date)
            summaryDetail = completedRecording.map { route in
                let distance = mapper.distance(
                    meters: route.distanceMeters,
                    measurementSystem: measurementSystem
                )
                return "\(distance) · \(elapsedText(at: date))"
            } ?? "No valid GPS points were recorded."
            replaceDraftPersistenceTask { [repository] in try? await repository.saveDraft(nil) }
            return nil
        }
        guard finishedActivity == .following else {
            summaryDetail = "\(elapsedText(at: date)) · \(currentDistanceText)"
            return nil
        }
        guard let breadcrumb = breadcrumbRecorder.finish(at: date) else {
            completedRecording = nil
            state.routePersistence.reset()
            summaryDetail = "No valid GPS points were recorded."
            return nil
        }
        let route = RideRoute(
            id: UUID(),
            name: "Ride · \(selectedRoute?.name ?? "Trail")",
            createdAt: breadcrumb.createdAt,
            updatedAt: date,
            segments: breadcrumb.segments
        )
        completedRecording = route
        state.routePersistence.beginCompletedRouteSave()
        let distance = mapper.distance(
            meters: route.distanceMeters,
            measurementSystem: measurementSystem
        )
        summaryDetail = "\(distance) · \(elapsedText(at: date))"
        return route
    }

    var currentGuidance: RideNavigationGuidance? {
        if activity == .following, let trailProgress {
            let remainingDistance = mapper.distance(
                meters: trailProgress.remainingDistanceMeters,
                measurementSystem: measurementSystem
            )
            let targetBearing = didAnnounceOffRoute
                ? RideRouteGeometry.bearingDegrees(
                    from: locationSnapshot.coordinate ?? trailProgress.rejoinCoordinate,
                    to: trailProgress.rejoinCoordinate
                )
                : trailProgress.targetBearingDegrees
            return RideNavigationGuidance(
                text: didAnnounceOffRoute ? "OFF TRAIL" : "ENDURO · FOLLOW THE ARROW",
                detail: didAnnounceOffRoute
                    ? offTrailDistanceText(trailProgress.distanceFromRouteMeters)
                    : "\(remainingDistance) remaining",
                systemImage: "location.north.fill",
                rotationDegrees: relativeBearingDegrees(targetBearing),
                emphasis: didAnnounceOffRoute ? .warning : .standard
            )
        }
        if activity == .following {
            return RideNavigationGuidance(
                text: "ENDURO · FOLLOW THE TRACK",
                detail: "Waiting for an accurate location",
                systemImage: "location.north.fill",
                emphasis: .standard
            )
        }
        if activity == .paused {
            return RideNavigationGuidance(
                text: "RECORDING PAUSED",
                systemImage: "pause.circle.fill",
                emphasis: .warning
            )
        }
        if activity == .navigating {
            let step = activeRoadStep
            let instruction = step?.instruction.isEmpty == false
                ? step?.instruction
                : "Continue toward the selected destination"
            let distance = step.flatMap(roadStepDistanceToManeuver).map {
                mapper.distance(meters: $0, measurementSystem: measurementSystem)
            }
            let rotation = step.flatMap(roadStepTargetBearing).map(relativeBearingDegrees) ?? .zero
            return RideNavigationGuidance(
                text: instruction ?? "ROAD NAVIGATION",
                detail: distance.map { "\($0) to next maneuver" },
                systemImage: "location.north.fill",
                rotationDegrees: rotation,
                emphasis: .standard
            )
        }
        return nil
    }

    func offTrailDistanceText(_ distanceMeters: Double) -> String {
        "\(mapper.distance(meters: distanceMeters, measurementSystem: measurementSystem)) to trail"
    }

    var currentDistanceText: String {
        let meters: Double
        if activity == .recording || activity == .paused {
            meters = recorder.snapshot(at: now()).route?.distanceMeters ?? .zero
        } else if let roadRoute {
            meters = roadRoute.distanceMeters
        } else {
            meters = trailMap.routeDistanceMeters
        }
        return mapper.distance(meters: meters, measurementSystem: measurementSystem)
    }

    var followCamera: NavigationMapCamera {
        guard let coordinate = locationSnapshot.coordinate else { return .automatic }
        let heading = isHeadingUp ? locationSnapshot.courseDegrees : nil
        return .follow(coordinate: mapMapper.coordinate(coordinate), headingDegrees: heading)
    }

    var isHeadingUp: Bool {
        appSettings.rideNavigation.mapOrientation == .headingUp
    }

    var allVisibleCoordinates: [NavigationMapCoordinate] {
        if selectedRoute != nil { return trailMap.overviewCoordinates }
        if let roadRoute { return mapMapper.coordinates(roadRoute.points) }
        return mapMapper.coordinates(recorder.snapshot(at: now()).route?.points.map(\.coordinate) ?? [])
    }

    func elapsedText(at date: Date) -> String {
        if activity == .recording || activity == .paused {
            return mapper.elapsed(recorder.snapshot(at: date).activeElapsedSeconds)
        }
        guard let activityStartedAt else { return "00:00" }
        return mapper.elapsed(max(date.timeIntervalSince(activityStartedAt), .zero))
    }

    public func discardActivity() {
        guard !state.routePersistence.status.isSaving else { return }
        let destinationToOpen = openIncomingDestinationAfterSummary ? pendingExternalDestination : nil
        recorder.reset()
        breadcrumbRecorder.reset()
        completedRecording = nil
        trailGuidance.reset()
        state.routePersistence.reset()
        frozenMiniMapScene = nil
        miniCompletionTitle = nil
        trailProgress = nil
        didAnnounceOffRoute = false
        lastRoadRerouteAt = nil
        selectedRoute = nil
        trailMap.reset()
        roadRoute = nil
        roadRoutes = []
        roadNavigationPurpose = nil
        trailExitPreview = nil
        selectedRoadRouteIndex = 0
        resetRoadStepGuidance()
        selectedDestination = nil
        activityStartedAt = nil
        activity = .preview
        mapDisplayStyle = .map
        isRerouting = false
        isCalculatingRoadRoutes = false
        isFindingTrailExit = false
        screen = .home
        stopClock()
        synchronizePresentationObservations()
        replaceDraftPersistenceTask { [repository] in try? await repository.saveDraft(nil) }
        render()
        if let destinationToOpen {
            pendingExternalDestination = nil
            openIncomingDestinationAfterSummary = false
            previewExternalDestination(destinationToOpen)
        }
    }

    func stopNavigationWithoutSummary() {
        routeTask?.cancel()
        trailExitTask?.cancel()
        if activity == .following || activity == .navigating {
            _ = breadcrumbRecorder.finish(at: now())
        }
        activityStartedAt = nil
        trailProgress = nil
        trailExitPreview = nil
        roadRoute = nil
        roadRoutes = []
        selectedDestination = nil
        roadNavigationPurpose = nil
        resetRoadStepGuidance()
        didAnnounceOffRoute = false
        lastRoadRerouteAt = nil
        isRerouting = false
        isFindingTrailExit = false
        stopClock()
    }

    enum CompletionReason: Equatable {
        case destinationReached
        case navigationEnded
        case trailComplete
        case trailEnded
        case exitPointReached
        case exitNavigationEnded
        case rideRecorded

        var title: String {
            switch self {
            case .destinationReached: "Destination reached"
            case .navigationEnded: "Navigation ended"
            case .trailComplete: "Trail complete"
            case .trailEnded: "Trail ended"
            case .exitPointReached: "Exit point reached"
            case .exitNavigationEnded: "Exit navigation ended"
            case .rideRecorded: "Ride recorded"
            }
        }

        var emitsSuccessFeedback: Bool {
            switch self {
            case .destinationReached, .trailComplete, .exitPointReached, .rideRecorded:
                true
            case .navigationEnded, .trailEnded, .exitNavigationEnded:
                false
            }
        }

        var isAutomaticArrival: Bool {
            switch self {
            case .destinationReached, .trailComplete, .exitPointReached:
                true
            case .navigationEnded, .trailEnded, .exitNavigationEnded, .rideRecorded:
                false
            }
        }
    }
}
