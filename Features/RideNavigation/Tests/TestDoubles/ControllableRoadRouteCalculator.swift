import EnvironmentDomain
import RideNavigationDomain

actor ControllableRoadRouteCalculator: RoadRouteCalculating {
    private var continuation: CheckedContinuation<[RoadNavigationRoute], any Error>?
    private(set) var lastPreferences: RoadRoutePreferences?
    private(set) var completionCount = 0

    func routes(
        from _: GeographicCoordinate,
        to _: NavigationPlace,
        preferences: RoadRoutePreferences
    ) async throws -> [RoadNavigationRoute] {
        lastPreferences = preferences
        let routes = try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
        completionCount += 1
        return routes
    }

    var hasPendingRequest: Bool {
        continuation != nil
    }

    func succeed(routes: [RoadNavigationRoute]) {
        continuation?.resume(returning: routes)
        continuation = nil
    }
}
