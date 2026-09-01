import EnvironmentDomain
import Foundation

public protocol RideRouteGuidancePlanning: Sendable {
    func makePlan(
        for route: RideRoute,
        direction: RideRouteDirection,
        configuration: RideRouteGuidanceConfiguration
    ) async -> RideRouteGuidancePlan?
}

public actor DefaultRideRouteGuidancePlanner: RideRouteGuidancePlanning {
    public init() {}

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
                if offset.isMultiple(of: PlannerConstants.cancellationCheckInterval),
                   Task.isCancelled {
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

    private enum PlannerConstants {
        static let cancellationCheckInterval = 1_024
    }
}

public struct RideRouteGuidancePlan: Sendable {
    public let direction: RideRouteDirection
    public let totalDistanceMeters: Double
    public let segmentRanges: [RideRouteGuidanceSegmentRange]

    let configuration: RideRouteGuidanceConfiguration
    let edges: [RideRouteGuidanceEdge]
    let spatialIndex: RideRouteGuidanceSpatialIndex

    init?(
        route: RideRoute,
        direction: RideRouteDirection,
        configuration: RideRouteGuidanceConfiguration,
        shouldCancel: () -> Bool = { false }
    ) {
        var builtEdges: [RideRouteGuidanceEdge] = []
        var builtSegmentRanges: [RideRouteGuidanceSegmentRange] = []
        var distanceAlongRouteMeters = 0.0
        for (segmentIndex, segment) in route.segments.enumerated() {
            let segmentStart = distanceAlongRouteMeters
            for (edgeIndex, pair) in zip(segment.points, segment.points.dropFirst()).enumerated() {
                if builtEdges.count.isMultiple(of: Constants.cancellationCheckInterval),
                   shouldCancel() {
                    return nil
                }
                let lengthMeters = RideRouteGeometry.distanceMeters(
                    from: pair.0.coordinate,
                    to: pair.1.coordinate
                )
                guard lengthMeters > .zero else { continue }
                builtEdges.append(
                    RideRouteGuidanceEdge(
                        globalIndex: builtEdges.count,
                        segmentIndex: segmentIndex,
                        edgeIndex: edgeIndex,
                        start: pair.0.coordinate,
                        end: pair.1.coordinate,
                        startDistanceMeters: distanceAlongRouteMeters,
                        lengthMeters: lengthMeters,
                        bearingDegrees: RideRouteGeometry.bearingDegrees(
                            from: pair.0.coordinate,
                            to: pair.1.coordinate
                        )
                    )
                )
                distanceAlongRouteMeters += lengthMeters
            }
            builtSegmentRanges.append(
                RideRouteGuidanceSegmentRange(
                    segmentIndex: segmentIndex,
                    distanceRange: RideRouteDistanceRange(
                        lowerBoundMeters: segmentStart,
                        upperBoundMeters: distanceAlongRouteMeters
                    )
                )
            )
        }
        guard let origin = builtEdges.first?.start,
              !builtEdges.isEmpty,
              !shouldCancel(),
              let builtSpatialIndex = RideRouteGuidanceSpatialIndex(
                  edges: builtEdges,
                  origin: origin,
                  cellSizeMeters: configuration.spatialCellSizeMeters,
                  shouldCancel: shouldCancel
              ) else { return nil }
        self.direction = direction
        totalDistanceMeters = distanceAlongRouteMeters
        segmentRanges = builtSegmentRanges
        self.configuration = configuration
        edges = builtEdges
        spatialIndex = builtSpatialIndex
    }

    public func entryMatch(for sample: RideRouteGuidanceSample) -> RideRouteEntryMatch? {
        let matches = projections(
            near: sample.coordinate,
            maximumDistanceMeters: configuration.entryDistanceMeters
        )
        guard let closest = matches.first else { return nil }
        guard hasReliableCourse(sample) else {
            return RideRouteEntryMatch(
                classification: .ambiguous,
                selectedProjection: nil,
                projections: matches
            )
        }
        let courseDegrees = sample.courseDegrees ?? .zero
        let tiedMatches = matches.filter {
            $0.distanceFromRouteMeters
                <= closest.distanceFromRouteMeters + configuration.entryProjectionTieMeters
        }
        let forward = occurrenceRepresentatives(in: tiedMatches.filter {
            angleDifference($0.localBearingDegrees, courseDegrees)
                <= configuration.compatibleCourseDifferenceDegrees
        })
        let reverse = occurrenceRepresentatives(in: tiedMatches.filter {
            angleDifference(oppositeBearing($0.localBearingDegrees), courseDegrees)
                <= configuration.compatibleCourseDifferenceDegrees
        })
        if forward.count == 1, reverse.isEmpty {
            return RideRouteEntryMatch(
                classification: .forward,
                selectedProjection: forward[0],
                projections: matches
            )
        }
        if reverse.count == 1, forward.isEmpty {
            return RideRouteEntryMatch(
                classification: .reverse,
                selectedProjection: reverse[0],
                projections: matches
            )
        }
        return RideRouteEntryMatch(
            classification: .ambiguous,
            selectedProjection: nil,
            projections: matches
        )
    }

    public func coordinate(atDistanceMeters distanceMeters: Double) -> GeographicCoordinate? {
        edge(containingDistanceMeters: distanceMeters)?.coordinate(
            atDistanceAlongRouteMeters: clampedDistance(distanceMeters)
        )
    }

    public func slices(in range: RideRouteDistanceRange) -> [RideRouteGuidanceSlice] {
        let lower = clampedDistance(range.lowerBoundMeters)
        let upper = clampedDistance(range.upperBoundMeters)
        guard upper >= lower else { return [] }
        var slices: [RideRouteGuidanceSlice] = []
        var activeSegmentIndex: Int?
        var activeCoordinates: [GeographicCoordinate] = []
        var activeLower = lower
        var activeUpper = lower
        for edge in edgesOverlapping(lowerBoundMeters: lower, upperBoundMeters: upper) {
            let edgeLower = max(lower, edge.startDistanceMeters)
            let edgeUpper = min(upper, edge.endDistanceMeters)
            guard edgeUpper >= edgeLower else { continue }
            if activeSegmentIndex != edge.segmentIndex {
                appendSlice(
                    to: &slices,
                    segmentIndex: activeSegmentIndex,
                    lowerBoundMeters: activeLower,
                    upperBoundMeters: activeUpper,
                    coordinates: activeCoordinates
                )
                activeSegmentIndex = edge.segmentIndex
                activeCoordinates = []
                activeLower = edgeLower
            }
            let start = edge.coordinate(atDistanceAlongRouteMeters: edgeLower)
            let end = edge.coordinate(atDistanceAlongRouteMeters: edgeUpper)
            if activeCoordinates.last != start {
                activeCoordinates.append(start)
            }
            if activeCoordinates.last != end {
                activeCoordinates.append(end)
            }
            activeUpper = edgeUpper
        }
        appendSlice(
            to: &slices,
            segmentIndex: activeSegmentIndex,
            lowerBoundMeters: activeLower,
            upperBoundMeters: activeUpper,
            coordinates: activeCoordinates
        )
        return slices
    }

    func hasReliableCourse(_ sample: RideRouteGuidanceSample) -> Bool {
        guard hasReliableTrackingAccuracy(sample),
              sample.speedKilometersPerHour >= configuration.reliableCourseSpeedKilometersPerHour,
              let courseAccuracy = sample.courseAccuracyDegrees,
              courseAccuracy >= .zero,
              courseAccuracy <= configuration.reliableCourseAccuracyDegrees,
              sample.courseDegrees != nil else { return false }
        return true
    }

    func edge(containingDistanceMeters distanceMeters: Double) -> RideRouteGuidanceEdge? {
        guard !edges.isEmpty else { return nil }
        let distance = clampedDistance(distanceMeters)
        var lower = edges.startIndex
        var upper = edges.endIndex
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if edges[middle].endDistanceMeters < distance {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return edges.indices.contains(lower) ? edges[lower] : edges.last
    }

    private func edgesOverlapping(
        lowerBoundMeters: Double,
        upperBoundMeters: Double
    ) -> ArraySlice<RideRouteGuidanceEdge> {
        guard let first = edge(containingDistanceMeters: lowerBoundMeters),
              let last = edge(containingDistanceMeters: upperBoundMeters) else { return [] }
        return edges[first.globalIndex...last.globalIndex]
    }

    func clampedDistance(_ distanceMeters: Double) -> Double {
        max(.zero, min(totalDistanceMeters, distanceMeters))
    }

    func signedAngle(from start: Double, to end: Double) -> Double {
        (end - start + 540).truncatingRemainder(dividingBy: 360) - 180
    }
}

private extension RideRouteGuidancePlan {
    private func appendSlice(
        to slices: inout [RideRouteGuidanceSlice],
        segmentIndex: Int?,
        lowerBoundMeters: Double,
        upperBoundMeters: Double,
        coordinates: [GeographicCoordinate]
    ) {
        guard let segmentIndex, coordinates.count >= 2 else { return }
        let simplifiedCoordinates = simplified(coordinates)
        slices.append(
            RideRouteGuidanceSlice(
                segmentIndex: segmentIndex,
                distanceRange: RideRouteDistanceRange(
                    lowerBoundMeters: lowerBoundMeters,
                    upperBoundMeters: upperBoundMeters
                ),
                coordinates: simplifiedCoordinates
            )
        )
    }

    private func simplified(
        _ coordinates: [GeographicCoordinate]
    ) -> [GeographicCoordinate] {
        guard let first = coordinates.first, let last = coordinates.last else { return [] }
        var result = [first]
        for coordinate in coordinates.dropFirst().dropLast() where
            RideRouteGeometry.distanceMeters(from: result[result.index(before: result.endIndex)], to: coordinate)
                >= Constants.minimumSlicePointSpacingMeters {
            result.append(coordinate)
        }
        if result.last != last {
            result.append(last)
        }
        return result
    }

    private func angleDifference(_ lhs: Double, _ rhs: Double) -> Double {
        abs(signedAngle(from: lhs, to: rhs))
    }

    private func oppositeBearing(_ bearing: Double) -> Double {
        (bearing + 180).truncatingRemainder(dividingBy: 360)
    }

    private func occurrenceRepresentatives(
        in projections: [RideRouteProjection]
    ) -> [RideRouteProjection] {
        let ordered = projections.sorted {
            if $0.position.segmentIndex == $1.position.segmentIndex {
                return $0.position.edgeIndex < $1.position.edgeIndex
            }
            return $0.position.segmentIndex < $1.position.segmentIndex
        }
        var groups: [[RideRouteProjection]] = []
        for projection in ordered {
            guard let previous = groups.last?.last,
                  previous.position.segmentIndex == projection.position.segmentIndex,
                  projection.position.distanceAlongRouteMeters
                    - previous.position.distanceAlongRouteMeters
                    <= Constants.maximumOccurrenceGapMeters,
                  angleDifference(
                    previous.localBearingDegrees,
                    projection.localBearingDegrees
                  ) <= configuration.compatibleCourseDifferenceDegrees else {
                groups.append([projection])
                continue
            }
            groups[groups.index(before: groups.endIndex)].append(projection)
        }
        return groups.compactMap { group in
            group.min { $0.distanceFromRouteMeters < $1.distanceFromRouteMeters }
        }
    }

    private enum Constants {
        static let cancellationCheckInterval = 1_024
        static let maximumOccurrenceGapMeters = 12.0
        static let minimumSlicePointSpacingMeters = 2.0
    }

}
