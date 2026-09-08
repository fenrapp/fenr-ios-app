import EnvironmentDomain

@MainActor
extension RideNavigationViewModel {
    func makeMiniMapScene(
        activity: RideNavigationActivitySnapshot? = nil,
        planning: RideNavigationPlanningSnapshot? = nil,
        location: RideNavigationLocationSnapshot? = nil
    ) -> NavigationMapScene {
        let activity = activity ?? activityController.snapshot
        let location = location ?? locationSnapshot
        return dependencies.mapSceneBuilder.makeMiniScene(
            from: makeMapScene(activity: activity, planning: planning, location: location),
            camera: followCamera(for: location),
            rejoinGuide: rejoinGuide(inFocusModeOnly: false, activity: activity, location: location)
        )
    }

    func makeMapScene(
        activity: RideNavigationActivitySnapshot? = nil,
        planning: RideNavigationPlanningSnapshot? = nil,
        location: RideNavigationLocationSnapshot? = nil
    ) -> NavigationMapScene {
        let activity = activity ?? activityController.snapshot
        let planning = planning ?? planningController.snapshot
        let location = location ?? locationSnapshot
        return dependencies.mapSceneBuilder.makeScene(.init(
            source: mapSource,
            displayStyle: mapDisplayStyle,
            camera: cameraMode,
            userCoordinate: location.coordinate,
            userHeadingDegrees: location.courseDegrees,
            trailOverlay: .init(
                hasSelectedRoute: planning.selectedRoute != nil,
                activity: activity.activity,
                isPresentingTrailExit: planning.trailExitPreview != nil || planning.roadNavigationPurpose == .trailExit,
                trailMap: activity.trailMap,
                guidancePlan: activity.trailGuidance.plan,
                guidance: activity.trailGuidance.guidance
            ),
            roadRoute: planning.roadRoute,
            roadRouteRevision: planning.roadRouteRevision,
            destination: planning.selectedDestination,
            trailExit: planning.trailExitPreview,
            trailExitRevision: planning.trailExitPreviewRevision,
            rejoinGuide: rejoinGuide(inFocusModeOnly: true, activity: activity, location: location),
            traces: routeTraces(activity: activity),
            lineAppearances: appSettings.rideNavigation.lineAppearances,
            showsCompassRing: appSettings.rideNavigation.showsCompassRing,
            showsRoadsInFocus: appSettings.rideNavigation.showsRoadsInFocus
        ))
    }

    func followCamera(for location: RideNavigationLocationSnapshot) -> NavigationMapCamera {
        guard let coordinate = location.coordinate else { return .automatic }
        return .follow(
            coordinate: dependencies.mapPresentationMapper.coordinate(coordinate),
            headingDegrees: isHeadingUp ? location.courseDegrees : nil
        )
    }

    private func rejoinGuide(
        inFocusModeOnly: Bool,
        activity: RideNavigationActivitySnapshot,
        location: RideNavigationLocationSnapshot
    ) -> [GeographicCoordinate]? {
        guard !inFocusModeOnly || mapDisplayStyle == .focus,
              activity.activity == .following, activity.didAnnounceOffRoute,
              let coordinate = location.coordinate,
              let rejoinCoordinate = activity.trailProgress?.rejoinCoordinate else { return nil }
        return [coordinate, rejoinCoordinate]
    }

    private func routeTraces(activity: RideNavigationActivitySnapshot) -> [RideNavigationMapSceneBuilder.RouteTrace] {
        [
            .init(idPrefix: "recorded", role: .recorded, segments: activity.recording.route?.segments ?? []),
            .init(idPrefix: "breadcrumb", role: .completed, segments: activity.breadcrumb.route?.segments ?? [])
        ]
    }
}
