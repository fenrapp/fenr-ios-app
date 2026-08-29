import EnvironmentDomain
@testable import RideNavigationDomain

struct StubRoadRouteCalculator: RoadRouteCalculating {
    let stubbedRoutes: [RoadNavigationRoute]

    func routes(
        from origin: GeographicCoordinate,
        to destination: NavigationPlace,
        preferences _: RoadRoutePreferences
    ) async throws -> [RoadNavigationRoute] {
        stubbedRoutes
    }
}
