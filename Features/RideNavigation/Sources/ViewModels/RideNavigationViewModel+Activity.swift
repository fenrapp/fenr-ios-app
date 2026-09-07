import Foundation
import RideNavigationDomain

@MainActor
extension RideNavigationViewModel {
    public func startRecording() {
        let update = activityController.startRecording(name: defaultRouteName(at: dependencies.timing.now()))
        receiveActivityUpdate(update)
    }

    public func toggleRecordingPause() {
        activityController.toggleRecordingPause()
        render()
    }

    public func finishActivity() {
        if let update = activityController.finishActivity() { receiveActivityUpdate(update) }
    }

    public func discardActivity() {
        guard !library.snapshot.persistence.status.isSaving else { return }
        let destination = openIncomingDestinationAfterSummary
            ? planningController.snapshot.pendingExternalDestination : nil
        activityController.discardActivity()
        frozenMiniMapScene = nil
        miniCompletionTitle = nil
        errorText = nil
        screen = .home
        mapDisplayStyle = .map
        synchronizePresentationObservations()
        render()
        if let destination {
            openIncomingDestinationAfterSummary = false
            previewExternalDestination(destination)
        }
    }

    var currentGuidance: RideNavigationGuidance? {
        if activityController.snapshot.activity == .following,
           let progress = activityController.snapshot.trailProgress {
            let remainingDistance = dependencies.presentationMapper.distance(
                meters: progress.remainingDistanceMeters,
                measurementSystem: measurementSystem
            )
            let targetBearing = activityController.snapshot.didAnnounceOffRoute
                ? RideRouteGeometry.bearingDegrees(
                    from: locationSnapshot.coordinate ?? progress.rejoinCoordinate,
                    to: progress.rejoinCoordinate
                )
                : progress.targetBearingDegrees
            return RideNavigationGuidance(
                text: activityController.snapshot.didAnnounceOffRoute
                    ? String(localized: .rideNavigationOffTrail)
                    : String(localized: .rideNavigationEnduroFollowArrow),
                detail: activityController.snapshot.didAnnounceOffRoute
                    ? offTrailDistanceText(progress.distanceFromRouteMeters)
                    : String(localized: .rideNavigationDistanceRemaining(remainingDistance)),
                systemImage: "location.north.fill",
                rotationDegrees: dependencies.locationGeometry.relativeBearingDegrees(
                    targetBearing,
                    courseDegrees: locationSnapshot.courseDegrees
                ),
                emphasis: activityController.snapshot.didAnnounceOffRoute ? .warning : .standard
            )
        }
        if activityController.snapshot.activity == .following {
            return RideNavigationGuidance(
                text: String(localized: .rideNavigationEnduroFollowTrack),
                detail: String(localized: .rideNavigationWaitingForAccurateLocation),
                systemImage: "location.north.fill",
                emphasis: .standard
            )
        }
        if activityController.snapshot.activity == .paused {
            return RideNavigationGuidance(
                text: String(localized: .rideNavigationRecordingPaused),
                systemImage: "pause.circle.fill",
                emphasis: .warning
            )
        }
        if activityController.snapshot.activity == .navigating {
            let step = activeRoadStep
            let instruction = step?.instruction.isEmpty == false
                ? step?.instruction
                : String(localized: .rideNavigationContinueToDestination)
            let distance = step.flatMap(roadStepDistanceToManeuver).map {
                dependencies.presentationMapper.distance(meters: $0, measurementSystem: measurementSystem)
            }
            let rotation = step.flatMap(roadStepTargetBearing).map {
                dependencies.locationGeometry.relativeBearingDegrees(
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
            dependencies.presentationMapper.distance(meters: distanceMeters, measurementSystem: measurementSystem)
        ))
    }

    var currentDistanceText: String {
        let meters: Double
        if activityController.snapshot.activity == .recording || activityController.snapshot.activity == .paused {
            meters = activityController.snapshot.recording.route?.distanceMeters ?? .zero
        } else if let roadRoute = planningController.snapshot.roadRoute {
            meters = roadRoute.distanceMeters
        } else {
            meters = activityController.snapshot.trailDistanceMeters
        }
        return dependencies.presentationMapper.distance(meters: meters, measurementSystem: measurementSystem)
    }

    var followCamera: NavigationMapCamera {
        guard let coordinate = locationSnapshot.coordinate else { return .automatic }
        let heading = isHeadingUp ? locationSnapshot.courseDegrees : nil
        return .follow(coordinate: dependencies.mapPresentationMapper.coordinate(coordinate), headingDegrees: heading)
    }

    var isHeadingUp: Bool {
        appSettings.rideNavigation.mapOrientation == .headingUp
    }

    var allVisibleCoordinates: [NavigationMapCoordinate] {
        if planningController.snapshot.selectedRoute != nil {
            return activityController.snapshot.trailOverviewCoordinates
        }
        if let roadRoute = planningController.snapshot.roadRoute {
            return dependencies.mapPresentationMapper.coordinates(roadRoute.points)
        }
        return dependencies.mapPresentationMapper.coordinates(
            activityController.snapshot.recording.route?.points.map(\.coordinate) ?? []
        )
    }

    func elapsedText() -> String {
        dependencies.presentationMapper.elapsed(activityController.snapshot.elapsedSeconds)
    }

}
