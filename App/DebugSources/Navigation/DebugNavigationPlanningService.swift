import EnvironmentDomain
import Foundation
import RideNavigationDomain

struct DebugNavigationPlanningService: PlaceSearching, RoadRouteCalculating,
    ExternalMapLinkResolving, TrailExitFinding {
    let destination: NavigationPlace

    func search(_ query: String, near coordinate: GeographicCoordinate?) async throws -> [NavigationPlace] {
        try Task.checkCancellation()
        return query.isEmpty ? [] : [destination]
    }

    func routes(
        from origin: GeographicCoordinate,
        to destination: NavigationPlace,
        preferences: RoadRoutePreferences
    ) async throws -> [RoadNavigationRoute] {
        try Task.checkCancellation()
        return [RoadNavigationRoute(
            name: destination.name,
            points: [origin, destination.coordinate],
            distanceMeters: 220,
            expectedTravelTime: 100,
            steps: [.init(instruction: String(localized: .uiTestingNavigationInstruction), distanceMeters: 220)]
        )]
    }

    func destination(from url: URL) async throws -> NavigationPlace {
        try Task.checkCancellation()
        return destination
    }

    func findExit(from origin: GeographicCoordinate, preferences: RoadRoutePreferences) async throws -> TrailExitRoute {
        let routes = try await routes(from: origin, to: destination, preferences: preferences)
        return .init(destination: destination, route: routes[0])
    }
}
