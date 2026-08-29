import EnvironmentDomain
import Foundation

public protocol PlaceSearching: Sendable {
    func search(_ query: String, near coordinate: GeographicCoordinate?) async throws -> [NavigationPlace]
}

public protocol RoadRouteCalculating: Sendable {
    func routes(
        from origin: GeographicCoordinate,
        to destination: NavigationPlace,
        preferences: RoadRoutePreferences
    ) async throws -> [RoadNavigationRoute]
}

public protocol ExternalMapLinkResolving: Sendable {
    func destination(from url: URL) async throws -> NavigationPlace
}

public protocol MapLinkRedirectResolving: Sendable {
    func resolve(_ url: URL) async throws -> URL
}

public protocol TrailExitFinding: Sendable {
    func findExit(
        from origin: GeographicCoordinate,
        preferences: RoadRoutePreferences
    ) async throws -> TrailExitRoute
}

public protocol TrailExitCandidateSearching: Sendable {
    func candidates(
        near origin: GeographicCoordinate,
        radiusMeters: Double
    ) async throws -> [NavigationPlace]
}

public protocol IncomingMapLinkStoring: Sendable {
    func save(_ link: IncomingMapLink) async throws
    func consume() async throws -> IncomingMapLink?
}

public extension RoadRouteCalculating {
    func route(
        from origin: GeographicCoordinate,
        to destination: NavigationPlace,
        preferences: RoadRoutePreferences
    ) async throws -> RoadNavigationRoute {
        guard let route = try await routes(
            from: origin,
            to: destination,
            preferences: preferences
        ).first else {
            throw RoadRouteCalculationError.routeUnavailable
        }
        return route
    }
}

public enum RoadRouteCalculationError: Error {
    case routeUnavailable
}

public enum ExternalMapLinkResolutionError: Error, Equatable {
    case unsupportedURL
    case destinationUnavailable
}

public enum TrailExitFindingError: Error, Equatable {
    case exitUnavailable
}
