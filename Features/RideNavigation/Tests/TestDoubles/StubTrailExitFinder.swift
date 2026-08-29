import EnvironmentDomain
import RideNavigationDomain

struct StubTrailExitFinder: TrailExitFinding {
    let result: TrailExitRoute?

    init(result: TrailExitRoute? = nil) {
        self.result = result
    }

    func findExit(
        from _: GeographicCoordinate,
        preferences _: RoadRoutePreferences
    ) async throws -> TrailExitRoute {
        guard let result else { throw TrailExitFindingError.exitUnavailable }
        return result
    }
}
