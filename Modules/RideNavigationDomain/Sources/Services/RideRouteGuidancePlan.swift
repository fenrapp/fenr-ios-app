import EnvironmentDomain
import Foundation

public struct RideRouteGuidancePlan: Sendable {
    public let direction: RideRouteDirection
    public let totalDistanceMeters: Double
    public let segmentRanges: [RideRouteGuidanceSegmentRange]

    let configuration: RideRouteGuidanceConfiguration
    let edges: [RideRouteGuidanceEdge]
    let spatialIndex: RideRouteGuidanceSpatialIndex
    let entryClassifier: RideRouteEntryClassifier

    init?(
        route: RideRoute,
        direction: RideRouteDirection,
        configuration: RideRouteGuidanceConfiguration,
        entryClassifier: RideRouteEntryClassifier,
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
        self.entryClassifier = entryClassifier
        edges = builtEdges
        spatialIndex = builtSpatialIndex
    }

    public func entryMatch(for sample: RideRouteGuidanceSample) -> RideRouteEntryMatch? {
        let matches = projections(
            near: sample.coordinate,
            maximumDistanceMeters: configuration.entryDistanceMeters
        )
        guard !matches.isEmpty else { return nil }
        guard hasReliableCourse(sample) else {
            return RideRouteEntryMatch(
                classification: .ambiguous,
                selectedProjection: nil,
                projections: matches
            )
        }
        return entryClassifier.classify(
            matches: matches,
            courseDegrees: sample.courseDegrees ?? .zero,
            configuration: configuration
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

    private enum Constants {
        static let cancellationCheckInterval = 1_024
        static let minimumSlicePointSpacingMeters = 2.0
    }

}
