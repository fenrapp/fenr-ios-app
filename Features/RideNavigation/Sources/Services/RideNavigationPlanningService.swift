import RideNavigationDomain

public struct RideNavigationPlanningService: Sendable {
    let roadRouteCalculator: any RoadRouteCalculating
    let externalMapLinkResolver: any ExternalMapLinkResolving
    let trailExitFinder: any TrailExitFinding

    public init(
        roadRouteCalculator: any RoadRouteCalculating,
        externalMapLinkResolver: any ExternalMapLinkResolving,
        trailExitFinder: any TrailExitFinding
    ) {
        self.roadRouteCalculator = roadRouteCalculator
        self.externalMapLinkResolver = externalMapLinkResolver
        self.trailExitFinder = trailExitFinder
    }
}
