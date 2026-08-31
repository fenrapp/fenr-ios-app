import EnvironmentDomain
import Foundation
import RideNavigationDomain

public struct RideNavigationPlanningService: Sendable {
    let placeSearch: any PlaceSearching
    let roadRouteCalculator: any RoadRouteCalculating
    let externalMapLinkResolver: any ExternalMapLinkResolving
    let trailExitFinder: any TrailExitFinding

    public init(
        placeSearch: any PlaceSearching,
        roadRouteCalculator: any RoadRouteCalculating,
        externalMapLinkResolver: any ExternalMapLinkResolving,
        trailExitFinder: any TrailExitFinding
    ) {
        self.placeSearch = placeSearch
        self.roadRouteCalculator = roadRouteCalculator
        self.externalMapLinkResolver = externalMapLinkResolver
        self.trailExitFinder = trailExitFinder
    }

    func search(_ query: String, near coordinate: GeographicCoordinate?) async throws -> [NavigationPlace] {
        try await placeSearch.search(query, near: coordinate)
    }

    func routes(
        from origin: GeographicCoordinate,
        to destination: NavigationPlace,
        preferences: RoadRoutePreferences
    ) async throws -> [RoadNavigationRoute] {
        try await roadRouteCalculator.routes(from: origin, to: destination, preferences: preferences)
    }

    func externalDestination(from url: URL) async throws -> NavigationPlace {
        try await externalMapLinkResolver.destination(from: url)
    }

    func trailExit(
        from origin: GeographicCoordinate,
        preferences: RoadRoutePreferences
    ) async throws -> TrailExitRoute {
        try await trailExitFinder.findExit(from: origin, preferences: preferences)
    }
}
