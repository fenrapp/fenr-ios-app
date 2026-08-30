import EnvironmentDomain
import Foundation

public enum RideRouteGeometry {
    public static func distanceMeters(
        from start: GeographicCoordinate,
        to end: GeographicCoordinate
    ) -> Double {
        let latitude1 = start.latitudeDegrees * .pi / 180
        let latitude2 = end.latitudeDegrees * .pi / 180
        let latitudeDelta = (end.latitudeDegrees - start.latitudeDegrees) * .pi / 180
        let longitudeDelta = (end.longitudeDegrees - start.longitudeDegrees) * .pi / 180
        let value = sin(latitudeDelta / 2) * sin(latitudeDelta / 2)
            + cos(latitude1) * cos(latitude2)
            * sin(longitudeDelta / 2) * sin(longitudeDelta / 2)
        let clampedValue = max(.zero, min(1, value))
        return Constants.earthRadiusMeters * 2 * atan2(
            sqrt(clampedValue),
            sqrt(1 - clampedValue)
        )
    }

    public static func distanceMeters(along points: [RideRoutePoint]) -> Double {
        zip(points, points.dropFirst()).reduce(.zero) { total, pair in
            total + distanceMeters(from: pair.0.coordinate, to: pair.1.coordinate)
        }
    }

    public static func closestDistanceMeters(
        from coordinate: GeographicCoordinate,
        to route: RideRoute
    ) -> Double? {
        route.segments.compactMap { segment in
            guard let first = segment.points.first else { return nil }
            guard segment.points.count > 1 else {
                return distanceMeters(from: coordinate, to: first.coordinate)
            }
            return zip(segment.points, segment.points.dropFirst()).map { pair in
                distanceToSegmentMeters(
                    coordinate,
                    start: pair.0.coordinate,
                    end: pair.1.coordinate
                )
            }.min()
        }.min()
    }

    public static func progress(
        from coordinate: GeographicCoordinate,
        along route: RideRoute,
        lookAheadMeters: Double,
        minimumDistanceAlongMeters: Double = .zero
    ) -> RideRouteProgress? {
        let geometry = routeGeometry(route)
        guard let fallbackCoordinate = geometry.lastCoordinate else { return nil }
        let minimumProgress = max(
            minimumDistanceAlongMeters - Constants.progressBacktrackToleranceMeters,
            .zero
        )
        let candidates = geometry.candidates(from: coordinate)
        let eligible = candidates.filter {
            $0.distanceAlongRouteMeters >= minimumProgress
        }
        let fallbackCandidate = geometry.coordinate(at: minimumProgress).map {
            ProgressCandidate(
                distanceFromRouteMeters: distanceMeters(from: coordinate, to: $0),
                distanceAlongRouteMeters: minimumProgress
            )
        }
        let precedes: (ProgressCandidate, ProgressCandidate) -> Bool = { lhs, rhs in
            progressCandidatePrecedes(
                lhs,
                rhs,
                referenceDistanceAlongMeters: minimumDistanceAlongMeters
            )
        }
        guard let closest = eligible.min(by: precedes) ?? fallbackCandidate
            ?? candidates.min(by: precedes) else { return nil }
        let targetDistance = min(
            closest.distanceAlongRouteMeters + max(lookAheadMeters, .zero),
            geometry.totalDistanceMeters
        )
        let rejoinCoordinate = geometry.coordinate(at: closest.distanceAlongRouteMeters)
            ?? fallbackCoordinate
        let target = geometry.coordinate(at: targetDistance) ?? fallbackCoordinate
        return RideRouteProgress(
            distanceFromRouteMeters: closest.distanceFromRouteMeters,
            distanceAlongRouteMeters: closest.distanceAlongRouteMeters,
            remainingDistanceMeters: max(
                geometry.totalDistanceMeters - closest.distanceAlongRouteMeters,
                .zero
            ),
            rejoinCoordinate: rejoinCoordinate,
            targetCoordinate: target,
            targetBearingDegrees: bearingDegrees(from: coordinate, to: target)
        )
    }

    public static func bearingDegrees(
        from start: GeographicCoordinate,
        to end: GeographicCoordinate
    ) -> Double {
        let latitude1 = start.latitudeDegrees * .pi / 180
        let latitude2 = end.latitudeDegrees * .pi / 180
        let longitudeDelta = (end.longitudeDegrees - start.longitudeDegrees) * .pi / 180
        let yValue = sin(longitudeDelta) * cos(latitude2)
        let xValue = cos(latitude1) * sin(latitude2)
            - sin(latitude1) * cos(latitude2) * cos(longitudeDelta)
        let degrees = atan2(yValue, xValue) * 180 / .pi
        return (degrees + 360).truncatingRemainder(dividingBy: 360)
    }

    public static func closestDistanceMeters(
        from coordinate: GeographicCoordinate,
        to points: [GeographicCoordinate]
    ) -> Double? {
        guard let first = points.first else { return nil }
        guard points.count > 1 else { return distanceMeters(from: coordinate, to: first) }
        return zip(points, points.dropFirst()).map { pair in
            distanceToSegmentMeters(coordinate, start: pair.0, end: pair.1)
        }.min()
    }

    private static func distanceToSegmentMeters(
        _ coordinate: GeographicCoordinate,
        start: GeographicCoordinate,
        end: GeographicCoordinate
    ) -> Double {
        let referenceLatitude = coordinate.latitudeDegrees * .pi / 180
        let startPoint = localPoint(start, origin: coordinate, referenceLatitude: referenceLatitude)
        let endPoint = localPoint(end, origin: coordinate, referenceLatitude: referenceLatitude)
        let deltaX = endPoint.x - startPoint.x
        let deltaY = endPoint.y - startPoint.y
        let squaredLength = deltaX * deltaX + deltaY * deltaY
        guard squaredLength > .zero else {
            return hypot(startPoint.x, startPoint.y)
        }
        let projection = max(
            .zero,
            min(1, -(startPoint.x * deltaX + startPoint.y * deltaY) / squaredLength)
        )
        return hypot(startPoint.x + projection * deltaX, startPoint.y + projection * deltaY)
    }

    private static func routeGeometry(_ route: RideRoute) -> RouteGeometry {
        var edges: [RouteEdge] = []
        var isolatedPoints: [RoutePointPosition] = []
        var distanceAlongRoute = 0.0
        var lastCoordinate: GeographicCoordinate?
        for segment in route.segments where !segment.points.isEmpty {
            if segment.points.count == 1, let coordinate = segment.points.first?.coordinate {
                isolatedPoints.append(
                    RoutePointPosition(
                        coordinate: coordinate,
                        distanceAlongRouteMeters: distanceAlongRoute
                    )
                )
                lastCoordinate = coordinate
                continue
            }
            for pair in zip(segment.points, segment.points.dropFirst()) {
                let length = distanceMeters(from: pair.0.coordinate, to: pair.1.coordinate)
                edges.append(
                    RouteEdge(
                        start: pair.0.coordinate,
                        end: pair.1.coordinate,
                        startDistanceMeters: distanceAlongRoute,
                        lengthMeters: length
                    )
                )
                distanceAlongRoute += length
                lastCoordinate = pair.1.coordinate
            }
        }
        return RouteGeometry(
            edges: edges,
            isolatedPoints: isolatedPoints,
            totalDistanceMeters: distanceAlongRoute,
            lastCoordinate: lastCoordinate
        )
    }

    private static func progressCandidatePrecedes(
        _ lhs: ProgressCandidate,
        _ rhs: ProgressCandidate,
        referenceDistanceAlongMeters: Double
    ) -> Bool {
        let distanceDelta = lhs.distanceFromRouteMeters - rhs.distanceFromRouteMeters
        if abs(distanceDelta) <= Constants.progressCandidateTieMeters {
            let lhsProgressDelta = abs(
                lhs.distanceAlongRouteMeters - referenceDistanceAlongMeters
            )
            let rhsProgressDelta = abs(
                rhs.distanceAlongRouteMeters - referenceDistanceAlongMeters
            )
            return lhsProgressDelta == rhsProgressDelta
                ? lhs.distanceAlongRouteMeters > rhs.distanceAlongRouteMeters
                : lhsProgressDelta < rhsProgressDelta
        }
        return distanceDelta < .zero
    }

    private static func localPoint(
        _ coordinate: GeographicCoordinate,
        origin: GeographicCoordinate,
        referenceLatitude: Double
    ) -> (x: Double, y: Double) {
        let longitudeDelta = (coordinate.longitudeDegrees - origin.longitudeDegrees) * .pi / 180
        let latitudeDelta = (coordinate.latitudeDegrees - origin.latitudeDegrees) * .pi / 180
        return (
            longitudeDelta * cos(referenceLatitude) * Constants.earthRadiusMeters,
            latitudeDelta * Constants.earthRadiusMeters
        )
    }

    private enum Constants {
        static let earthRadiusMeters = 6_371_000.0
        static let progressBacktrackToleranceMeters = 30.0
        static let progressCandidateTieMeters = 3.0
    }
}

private extension RideRouteGeometry {
    struct ProgressCandidate {
        let distanceFromRouteMeters: Double
        let distanceAlongRouteMeters: Double
    }

    struct RoutePointPosition {
        let coordinate: GeographicCoordinate
        let distanceAlongRouteMeters: Double
    }

    struct RouteEdge {
        let start: GeographicCoordinate
        let end: GeographicCoordinate
        let startDistanceMeters: Double
        let lengthMeters: Double

        func candidate(from coordinate: GeographicCoordinate) -> ProgressCandidate {
            let referenceLatitude = coordinate.latitudeDegrees * .pi / 180
            let startPoint = RideRouteGeometry.localPoint(
                start,
                origin: coordinate,
                referenceLatitude: referenceLatitude
            )
            let endPoint = RideRouteGeometry.localPoint(
                end,
                origin: coordinate,
                referenceLatitude: referenceLatitude
            )
            let deltaX = endPoint.x - startPoint.x
            let deltaY = endPoint.y - startPoint.y
            let squaredLength = deltaX * deltaX + deltaY * deltaY
            let projection = squaredLength > .zero
                ? max(.zero, min(1, -(startPoint.x * deltaX + startPoint.y * deltaY) / squaredLength))
                : .zero
            return ProgressCandidate(
                distanceFromRouteMeters: hypot(
                    startPoint.x + projection * deltaX,
                    startPoint.y + projection * deltaY
                ),
                distanceAlongRouteMeters: startDistanceMeters + lengthMeters * projection
            )
        }

        func coordinate(at distanceMeters: Double) -> GeographicCoordinate? {
            guard lengthMeters > .zero else { return start }
            let progress = max(.zero, min(1, distanceMeters / lengthMeters))
            return GeographicCoordinate(
                latitudeDegrees: start.latitudeDegrees
                    + (end.latitudeDegrees - start.latitudeDegrees) * progress,
                longitudeDegrees: start.longitudeDegrees
                    + (end.longitudeDegrees - start.longitudeDegrees) * progress
            )
        }
    }

    struct RouteGeometry {
        let edges: [RouteEdge]
        let isolatedPoints: [RoutePointPosition]
        let totalDistanceMeters: Double
        let lastCoordinate: GeographicCoordinate?

        func candidates(from coordinate: GeographicCoordinate) -> [ProgressCandidate] {
            edges.map { $0.candidate(from: coordinate) } + isolatedPoints.map {
                ProgressCandidate(
                    distanceFromRouteMeters: RideRouteGeometry.distanceMeters(
                        from: coordinate,
                        to: $0.coordinate
                    ),
                    distanceAlongRouteMeters: $0.distanceAlongRouteMeters
                )
            }
        }

        func coordinate(at distanceMeters: Double) -> GeographicCoordinate? {
            guard let edge = edges.first(where: {
                distanceMeters <= $0.startDistanceMeters + $0.lengthMeters
            }) else { return lastCoordinate }
            return edge.coordinate(at: distanceMeters - edge.startDistanceMeters)
        }
    }
}
