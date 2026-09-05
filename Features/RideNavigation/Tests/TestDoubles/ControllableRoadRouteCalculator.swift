import EnvironmentDomain
import RideNavigationDomain

actor ControllableRoadRouteCalculator: RoadRouteCalculating {
    enum Failure: Error {
        case unavailable
    }

    private var continuations: [CheckedContinuation<[RoadNavigationRoute], any Error>] = []
    private(set) var lastPreferences: RoadRoutePreferences?
    private(set) var completionCount = 0

    func routes(
        from _: GeographicCoordinate,
        to _: NavigationPlace,
        preferences: RoadRoutePreferences
    ) async throws -> [RoadNavigationRoute] {
        lastPreferences = preferences
        let routes = try await withCheckedThrowingContinuation { continuation in
            continuations.append(continuation)
        }
        completionCount += 1
        return routes
    }

    var hasPendingRequest: Bool {
        !continuations.isEmpty
    }

    func succeed(routes: [RoadNavigationRoute]) {
        guard !continuations.isEmpty else { return }
        continuations.removeFirst().resume(returning: routes)
    }

    var requestCount: Int {
        continuations.count
    }

    func succeed(request index: Int, routes: [RoadNavigationRoute]) {
        continuations.remove(at: index).resume(returning: routes)
    }

    func fail(request index: Int, error: any Error = Failure.unavailable) {
        continuations.remove(at: index).resume(throwing: error)
    }
}
