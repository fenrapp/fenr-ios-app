import EnvironmentDomain
import RideNavigationDomain

actor RecordingTrailExitRouteCalculator: RoadRouteCalculating {
    struct RouteValue: Sendable {
        let distanceMeters: Double
        let travelTime: Double
    }

    enum Outcome: Sendable {
        case route(RouteValue)
        case unavailable
        case cancellation
    }

    private let outcomes: [String: Outcome]
    private var destinations: [String] = []
    private var preferences: [RoadRoutePreferences] = []

    init(values: [String: RouteValue]) {
        outcomes = values.mapValues(Outcome.route)
    }

    init(outcomes: [String: Outcome]) {
        self.outcomes = outcomes
    }

    func routes(
        from origin: GeographicCoordinate,
        to destination: NavigationPlace,
        preferences: RoadRoutePreferences
    ) async throws -> [RoadNavigationRoute] {
        destinations.append(destination.name)
        self.preferences.append(preferences)
        guard let outcome = outcomes[destination.name] else {
            throw RoadRouteCalculationError.routeUnavailable
        }
        let value: RouteValue
        switch outcome {
        case .route(let routeValue):
            value = routeValue
        case .unavailable:
            throw RoadRouteCalculationError.routeUnavailable
        case .cancellation:
            throw CancellationError()
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
