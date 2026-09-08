import RideNavigationDomain

public struct RideNavigationActivityDependencies: Sendable {
    let library: RideNavigationLibraryController
    let planning: RideNavigationPlanningController
    let trailGuidance: RideNavigationTrailGuidanceController
    let trailMapPreparer: any RideNavigationTrailMapPreparing
    let trailMap: RideNavigationTrailMapController
    let guidance: any NavigationGuidanceClient
    let locationGeometry: RideNavigationLocationGeometry
    let timing: RideNavigationTiming

    public init(
        library: RideNavigationLibraryController,
        planning: RideNavigationPlanningController,
        trailGuidance: RideNavigationTrailGuidanceController,
        trailMapPreparer: any RideNavigationTrailMapPreparing,
        trailMap: RideNavigationTrailMapController,
        guidance: any NavigationGuidanceClient,
        locationGeometry: RideNavigationLocationGeometry,
        timing: RideNavigationTiming
    ) {
        self.library = library
        self.planning = planning
        self.trailGuidance = trailGuidance
        self.trailMapPreparer = trailMapPreparer
        self.trailMap = trailMap
        self.guidance = guidance
        self.locationGeometry = locationGeometry
        self.timing = timing
    }
}
