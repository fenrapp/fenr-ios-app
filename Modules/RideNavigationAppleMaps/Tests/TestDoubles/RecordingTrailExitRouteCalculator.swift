import EnvironmentDomain
import RideNavigationDomain

actor RecordingTrailExitRouteCalculator: RoadRouteCalculating {
    struct RouteValue: Sendable {
        let distanceMeters: Double
        let travelTime: Double
    }

    private let values: [String: RouteValue]
    private var destinations: [String] = []
    private var preferences: [RoadRoutePreferences] = []

    init(values: [String: RouteValue]) {
        self.values = values
    }

    func routes(
        from origin: GeographicCoordinate,
        to destination: NavigationPlace,
        preferences: RoadRoutePreferences
    ) async throws -> [RoadNavigationRoute] {
        destinations.append(destination.name)
        self.preferences.append(preferences)
        guard let value = values[destination.name] else {
            throw RoadRouteCalculationError.routeUnavailable
        }
        return [
            RoadNavigationRoute(
                name: destination.name,
                points: [origin, destination.coordinate],
                distanceMeters: value.distanceMeters,
                expectedTravelTime: value.travelTime,
                steps: []
            )
        ]
    }

    func requestedDestinations() -> [String] {
        destinations
    }

    func requestedPreferences() -> [RoadRoutePreferences] {
        preferences
    }
}
