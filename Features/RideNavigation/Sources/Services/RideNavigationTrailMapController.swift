@MainActor
public final class RideNavigationTrailMapController {
    struct PresentationSnapshot: Equatable, Sendable {
        let segments: [[NavigationMapCoordinate]]
        let startCoordinate: NavigationMapCoordinate?
        let finishCoordinate: NavigationMapCoordinate?
        let revision: Int
        let completedPolylines: [NavigationMapPolyline]
    }

    private var routeSegments: [[NavigationMapCoordinate]] = []
    private(set) var overviewCoordinates: [NavigationMapCoordinate] = []
    private var startCoordinate: NavigationMapCoordinate?
    private var finishCoordinate: NavigationMapCoordinate?
    private(set) var routeDistanceMeters = 0.0
    private var routeRevision = 0
    private var completionChunks: [RideNavigationTrailMapPlan.CompletionChunk] = []
    private var completedPolylines: [NavigationMapPolyline] = []
    private var partialCompletedPolyline: NavigationMapPolyline?
    private var nextCompletionChunkIndex = 0
    private var completedDistanceMeters = 0.0

    public init() {}

    var presentationSnapshot: PresentationSnapshot {
        var orderedCompletedPolylines = completedPolylines
        if let partialCompletedPolyline {
            orderedCompletedPolylines.append(partialCompletedPolyline)
        }
        return PresentationSnapshot(
            segments: routeSegments,
            startCoordinate: startCoordinate,
            finishCoordinate: finishCoordinate,
            revision: routeRevision,
            completedPolylines: orderedCompletedPolylines
        )
    }

    func apply(_ plan: RideNavigationTrailMapPlan) {
        routeSegments = plan.routeSegments
        overviewCoordinates = plan.overviewCoordinates
        startCoordinate = plan.startCoordinate
        finishCoordinate = plan.finishCoordinate
        routeDistanceMeters = plan.distanceMeters
        completionChunks = plan.completionChunks
        routeRevision &+= 1
        resetCompletion()
    }

    func advanceCompletion(to distanceMeters: Double) {
        let target = min(max(distanceMeters, completedDistanceMeters), routeDistanceMeters)
        guard target > completedDistanceMeters else { return }
        partialCompletedPolyline = nil
        while nextCompletionChunkIndex < completionChunks.count {
            let chunk = completionChunks[nextCompletionChunkIndex]
            guard chunk.upperBoundMeters <= target else { break }
            completedPolylines.append(polyline(for: chunk))
            nextCompletionChunkIndex += 1
        }
        if nextCompletionChunkIndex < completionChunks.count {
            let chunk = completionChunks[nextCompletionChunkIndex]
            partialCompletedPolyline = partialPolyline(for: chunk, at: target)
        }
        completedDistanceMeters = target
    }

    func appendCompletedPolylines(to polylines: inout [NavigationMapPolyline]) {
        polylines.append(contentsOf: presentationSnapshot.completedPolylines)
    }

    func resetCompletion() {
        completedPolylines = []
        partialCompletedPolyline = nil
        nextCompletionChunkIndex = 0
        completedDistanceMeters = .zero
    }

    func reset() {
        routeSegments = []
        overviewCoordinates = []
        startCoordinate = nil
        finishCoordinate = nil
        routeDistanceMeters = .zero
        completionChunks = []
        routeRevision &+= 1
        resetCompletion()
    }

    private func polyline(
        for chunk: RideNavigationTrailMapPlan.CompletionChunk
    ) -> NavigationMapPolyline {
        NavigationMapPolyline(
            id: "trail-completed-\(routeRevision)-\(chunk.id)",
            points: chunk.points,
            role: .trailCompleted,
            revision: chunk.points.count * 2
        )
    }

    private func partialPolyline(
        for chunk: RideNavigationTrailMapPlan.CompletionChunk,
        at distanceMeters: Double
    ) -> NavigationMapPolyline? {
        var lowerBound = 0
        var upperBound = chunk.distancesMeters.count
        while lowerBound < upperBound {
            let midpoint = (lowerBound + upperBound) / 2
            if chunk.distancesMeters[midpoint] <= distanceMeters {
                lowerBound = midpoint + 1
            } else {
                upperBound = midpoint
            }
        }
        guard lowerBound > 0 else { return nil }
        var points = Array(chunk.points.prefix(lowerBound))
        if lowerBound < chunk.points.count {
            let previousDistance = chunk.distancesMeters[lowerBound - 1]
            let nextDistance = chunk.distancesMeters[lowerBound]
            if distanceMeters > previousDistance, nextDistance > previousDistance {
                points.append(interpolate(
                    from: chunk.points[lowerBound - 1],
                    to: chunk.points[lowerBound],
                    fraction: (distanceMeters - previousDistance) / (nextDistance - previousDistance)
                ))
            }
        }
        guard points.count > 1 else { return nil }
        return NavigationMapPolyline(
            id: "trail-completed-\(routeRevision)-\(chunk.id)",
            points: points,
            role: .trailCompleted,
            revision: Int((distanceMeters * 10).rounded()) * 2 + 1
        )
    }

    private func interpolate(
        from start: NavigationMapCoordinate,
        to end: NavigationMapCoordinate,
        fraction: Double
    ) -> NavigationMapCoordinate {
        let value = min(max(fraction, .zero), 1)
        return NavigationMapCoordinate(
            latitudeDegrees: start.latitudeDegrees
                + (end.latitudeDegrees - start.latitudeDegrees) * value,
            longitudeDegrees: start.longitudeDegrees
                + (end.longitudeDegrees - start.longitudeDegrees) * value
        )!
    }
}
