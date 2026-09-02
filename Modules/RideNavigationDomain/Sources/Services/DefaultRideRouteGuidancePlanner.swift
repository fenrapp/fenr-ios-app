import Foundation

public protocol RideRouteGuidancePlanning: Sendable {
    func makePlan(
        for route: RideRoute,
        direction: RideRouteDirection,
        configuration: RideRouteGuidanceConfiguration
    ) async -> RideRouteGuidancePlan?
}

public struct DefaultRideRouteGuidancePlanner: RideRouteGuidancePlanning {
    private let entryClassifier: RideRouteEntryClassifier

    public init(entryClassifier: RideRouteEntryClassifier) {
        self.entryClassifier = entryClassifier
    }

    public func makePlan(
        for route: RideRoute,
        direction: RideRouteDirection,
        configuration: RideRouteGuidanceConfiguration = .standard
    ) async -> RideRouteGuidancePlan? {
        guard let orientedRoute = orientedRoute(route, direction: direction) else { return nil }
        return RideRouteGuidancePlan(
            route: orientedRoute,
            direction: direction,
            configuration: configuration,
            entryClassifier: entryClassifier,
            shouldCancel: { Task.isCancelled }
        )
    }

    private func orientedRoute(
        _ route: RideRoute,
        direction: RideRouteDirection
    ) -> RideRoute? {
        guard !Task.isCancelled else { return nil }
        guard direction == .reverse else { return route }
        var segments: [RideRouteSegment] = []
        segments.reserveCapacity(route.segments.count)
        for segment in route.segments.reversed() {
            var points: [RideRoutePoint] = []
            points.reserveCapacity(segment.points.count)
            for (offset, point) in segment.points.reversed().enumerated() {
                if offset.isMultiple(of: Constants.cancellationCheckInterval), Task.isCancelled {
                    return nil
                }
                points.append(point)
            }
            segments.append(RideRouteSegment(id: segment.id, points: points))
        }
        return RideRoute(
            id: route.id,
            name: route.name,
            createdAt: route.createdAt,
            updatedAt: route.updatedAt,
            segments: segments
        )
    }

    private enum Constants {
        static let cancellationCheckInterval = 1_024
    }
}
