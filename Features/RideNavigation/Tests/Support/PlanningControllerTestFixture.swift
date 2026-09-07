import Foundation
@testable import RideNavigation

@MainActor
struct PlanningControllerTestFixture {
    let controller: RideNavigationPlanningController
    let placeSearch: ControllablePlaceSearch
    let roadCalculator: ControllableRoadRouteCalculator
    let linkResolver: ControllableExternalMapLinkResolver
    let exitFinder: ControllableTrailExitFinder

    static func make() -> Self {
        let placeSearch = ControllablePlaceSearch()
        let roadCalculator = ControllableRoadRouteCalculator()
        let linkResolver = ControllableExternalMapLinkResolver()
        let exitFinder = ControllableTrailExitFinder()
        let timing = RideNavigationTiming(
            now: { Date(timeIntervalSince1970: 1_700_000_000) },
            sleep: { _ in try Task.checkCancellation() }
        )
        return Self(
            controller: RideNavigationPlanningController(
                planning: RideNavigationPlanningService(
                    roadRouteCalculator: roadCalculator,
                    externalMapLinkResolver: linkResolver,
                    trailExitFinder: exitFinder
                ),
                search: RideNavigationSearchService(placeSearch: placeSearch, sleep: timing.sleep),
                timing: timing
            ),
            placeSearch: placeSearch,
            roadCalculator: roadCalculator,
            linkResolver: linkResolver,
            exitFinder: exitFinder
        )
    }
}
