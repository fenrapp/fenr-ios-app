import Foundation
@testable import RideNavigation
import RideNavigationDomain

@MainActor
struct ActivityControllerTestFixture {
    let activity: RideNavigationActivityController
    let library: RideNavigationLibraryController
    let planning: RideNavigationPlanningController
    let roadCalculator: ControllableRoadRouteCalculator
    let guidance: NoOpNavigationGuidanceClient

    static func make(
        timing: RideNavigationTiming,
        trailMapPreparer: (any RideNavigationTrailMapPreparing)? = nil
    ) -> Self {
        let library = makeLibrary(timing: timing)
        let roadCalculator = ControllableRoadRouteCalculator()
        let planning = makePlanning(timing: timing, roadCalculator: roadCalculator)
        let guidance = NoOpNavigationGuidanceClient()
        let mapMapper = RideNavigationMapPresentationMapper()
        let activity = RideNavigationActivityController(
            dependencies: RideNavigationActivityDependencies(
                library: library,
                planning: planning,
                trailGuidance: RideNavigationTrailGuidanceController(
                    planner: DefaultRideRouteGuidancePlanner(entryClassifier: RideRouteEntryClassifier()),
                    projectionSelector: RideRouteProjectionSelector()
                ),
                trailMapPreparer: trailMapPreparer ?? RideNavigationTrailMapPreparer(mapper: mapMapper),
                trailMap: RideNavigationTrailMapController(),
                guidance: guidance,
                locationGeometry: RideNavigationLocationGeometry(),
                timing: timing
            ),
            recorder: RideRouteRecorder(),
            breadcrumbRecorder: RideRouteRecorder()
        )
        return Self(
            activity: activity, library: library, planning: planning,
            roadCalculator: roadCalculator, guidance: guidance
        )
    }

    func start() {
        library.start()
        planning.start()
        activity.start()
    }

    func stop() {
        activity.stop()
        planning.stop()
        library.stop()
    }

    func receive(index: Int, seconds: TimeInterval) {
        activity.receiveLocation(
            ActivityControllerTestData.location(index: index, seconds: seconds),
            speedKilometersPerHour: 18, preferences: .init()
        )
    }

    static func prepareMap(route: RideRoute) async -> RideNavigationTrailMapPlan? {
        let preparer = RideNavigationTrailMapPreparer(mapper: RideNavigationMapPresentationMapper())
        return await preparer.prepare(route: route, direction: .forward)
    }

    private static func makeLibrary(timing: RideNavigationTiming) -> RideNavigationLibraryController {
        RideNavigationLibraryController(
            routeLibrary: RideNavigationRouteLibraryService(
                repository: StubRecordedRouteRepository(),
                importer: StubGPXRouteImporter(),
                exporter: StubGPXRouteExporter()
            ),
            timing: timing
        )
    }

    private static func makePlanning(
        timing: RideNavigationTiming,
        roadCalculator: ControllableRoadRouteCalculator
    ) -> RideNavigationPlanningController {
        RideNavigationPlanningController(
            planning: RideNavigationPlanningService(
                roadRouteCalculator: roadCalculator,
                externalMapLinkResolver: StubExternalMapLinkResolver(),
                trailExitFinder: StubTrailExitFinder()
            ),
            search: RideNavigationSearchService(placeSearch: ControllablePlaceSearch(), sleep: timing.sleep),
            timing: timing
        )
    }
}
