import Foundation
import RideNavigationDomain
@MainActor
extension RideNavigationViewModel {
    public func startRecording() {
        let date = now()
        library.resetPersistence()
        recorder.start(at: date, name: defaultRouteName(at: date))
        completedRecording = nil
        activityStartedAt = date
        screen = .map
        activity = .recording
        mapDisplayStyle = .map
        cameraMode = followCamera
        startClock()
        render()
        announce(String(localized: .rideNavigationAnnouncementRecordingStarted))
    }
    public func toggleRecordingPause() {
        let date = now()
        switch activity {
        case .recording:
            recorder.pause(at: date)
            activity = .paused
            scheduleDraftSave()
            announce(String(localized: .rideNavigationAnnouncementRecordingPaused))
        case .paused:
            recorder.resume(at: date)
            activity = .recording
            announce(String(localized: .rideNavigationAnnouncementRecordingResumed))
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
        let emptyRecording = reason == .rideRecorded && completedRecording == nil
        state.summaryIsSuccessful = !emptyRecording
        summaryTitle = emptyRecording ? String(localized: .rideNavigationRecordingEnded) : reason.title
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
        if reason.emitsSuccessFeedback, !emptyRecording {
            replaceFeedbackTask { [guidance] in await guidance.notifySuccess() }
        }
        if let completedTrailRouteToSave {
            beginCompletedRouteSave(completedTrailRouteToSave)
        }
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
                text: didAnnounceOffRoute
                    ? String(localized: .rideNavigationOffTrail)
                    : String(localized: .rideNavigationEnduroFollowArrow),
                detail: didAnnounceOffRoute
                    ? offTrailDistanceText(trailProgress.distanceFromRouteMeters)
                    : String(localized: .rideNavigationDistanceRemaining(remainingDistance)),
                systemImage: "location.north.fill",
                rotationDegrees: locationGeometry.relativeBearingDegrees(
                    targetBearing,
                    courseDegrees: locationSnapshot.courseDegrees
                ),
                emphasis: didAnnounceOffRoute ? .warning : .standard
            )
        }
        if activity == .following {
            return RideNavigationGuidance(
                text: String(localized: .rideNavigationEnduroFollowTrack),
                detail: String(localized: .rideNavigationWaitingForAccurateLocation),
                systemImage: "location.north.fill",
                emphasis: .standard
            )
        }
        if activity == .paused {
            return RideNavigationGuidance(
                text: String(localized: .rideNavigationRecordingPaused),
                systemImage: "pause.circle.fill",
                emphasis: .warning
            )
        }
        if activity == .navigating {
            let step = activeRoadStep
            let instruction = step?.instruction.isEmpty == false
                ? step?.instruction
                : String(localized: .rideNavigationContinueToDestination)
            let distance = step.flatMap(roadStepDistanceToManeuver).map {
                mapper.distance(meters: $0, measurementSystem: measurementSystem)
            }
            let rotation = step.flatMap(roadStepTargetBearing).map {
                locationGeometry.relativeBearingDegrees(
                    $0,
                    courseDegrees: locationSnapshot.courseDegrees
                )
            } ?? .zero
            return RideNavigationGuidance(
                text: instruction ?? String(localized: .rideNavigationRoadNavigation),
                detail: distance.map { String(localized: .rideNavigationDistanceToNextManeuver($0)) },
                systemImage: "location.north.fill",
                rotationDegrees: rotation,
                emphasis: .standard
            )
        }
            return nil
        }
    func offTrailDistanceText(_ distanceMeters: Double) -> String {
        String(localized: .rideNavigationDistanceToTrail(
            mapper.distance(meters: distanceMeters, measurementSystem: measurementSystem)
        ))
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
        guard !library.snapshot.persistence.status.isSaving else { return }
        let destinationToOpen = openIncomingDestinationAfterSummary ? pendingExternalDestination : nil
        recorder.reset()
        breadcrumbRecorder.reset()
        completedRecording = nil
        trailGuidance.reset()
        library.resetPersistence()
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
        library.clearDraft()
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
            case .destinationReached: String(localized: .rideNavigationSummaryDestinationReached)
            case .navigationEnded: String(localized: .rideNavigationSummaryNavigationEnded)
            case .trailComplete: String(localized: .rideNavigationSummaryTrailComplete)
            case .trailEnded: String(localized: .rideNavigationSummaryTrailEnded)
            case .exitPointReached: String(localized: .rideNavigationSummaryExitPointReached)
            case .exitNavigationEnded: String(localized: .rideNavigationSummaryExitNavigationEnded)
            case .rideRecorded: String(localized: .rideNavigationSummaryRideRecorded)
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
