import EnvironmentDomain
import RideNavigationDomain

actor ControllableTrailExitFinder: TrailExitFinding {
    enum Failure: Error {
        case unavailable
    }

    private var requests: [CheckedContinuation<TrailExitRoute, any Error>] = []

    func findExit(
        from _: GeographicCoordinate,
        preferences _: RoadRoutePreferences
    ) async throws -> TrailExitRoute {
        try await withCheckedThrowingContinuation { continuation in
            requests.append(continuation)
        }
    }

    var requestCount: Int {
        requests.count
    }

    func succeed(request index: Int, exit: TrailExitRoute) {
        requests.remove(at: index).resume(returning: exit)
    }

    func fail(request index: Int) {
        requests.remove(at: index).resume(throwing: Failure.unavailable)
    }
}
