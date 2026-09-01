import EnvironmentDomain
import Foundation

extension RideRouteGuidancePlan {
    func projections(
        near coordinate: GeographicCoordinate,
        maximumDistanceMeters: Double
    ) -> [RideRouteProjection] {
        let matches = spatialIndex.edgeIndices(
            near: coordinate,
            radiusMeters: maximumDistanceMeters
        ).map { edges[$0].projection(from: coordinate) }
            .filter { $0.distanceFromRouteMeters <= maximumDistanceMeters }
            .sorted(by: projectionPrecedes)
        return deduplicatedProjections(matches)
    }

    func corridor(from distanceMeters: Double) -> RideRouteDistanceRange {
        RideRouteDistanceRange(
            lowerBoundMeters: clampedDistance(distanceMeters),
            upperBoundMeters: clampedDistance(distanceMeters + configuration.activeCorridorMeters)
        )
    }

    func indicators(in range: RideRouteDistanceRange) -> [RideRouteGuidanceIndicator] {
        let firstDistance = floor(range.lowerBoundMeters / configuration.indicatorSpacingMeters)
            * configuration.indicatorSpacingMeters + configuration.indicatorSpacingMeters
        var retained: [RideRouteGuidanceIndicator] = []
        for offset in 0..<configuration.maximumActiveIndicators {
            let distance = firstDistance + Double(offset) * configuration.indicatorSpacingMeters
            guard distance <= range.upperBoundMeters,
                  let edge = edge(containingDistanceMeters: distance) else { continue }
            let position = edge.position(atDistanceAlongRouteMeters: distance)
            let coordinate = edge.coordinate(atDistanceAlongRouteMeters: distance)
            guard retained.allSatisfy({
                RideRouteGeometry.distanceMeters(from: $0.coordinate, to: coordinate)
                    >= Constants.minimumIndicatorSeparationMeters
            }) else { continue }
            retained.append(RideRouteGuidanceIndicator(
                id: "\(position.segmentIndex):\(position.edgeIndex):\(Int(distance.rounded()))",
                coordinate: coordinate,
                bearingDegrees: edge.bearingDegrees
            ))
        }
        return retained
    }

    func nextDecision(after distanceMeters: Double) -> RideRouteGuidanceDecision? {
        let limit = min(distanceMeters + configuration.decisionLookAheadMeters, totalDistanceMeters)
        guard let currentEdge = edge(containingDistanceMeters: distanceMeters) else { return nil }
        for edgeIndex in currentEdge.globalIndex..<edges.endIndex {
            let expected = edges[edgeIndex]
            guard expected.startDistanceMeters <= limit else { break }
            if edgeIndex > currentEdge.globalIndex,
               let vertexDecision = vertexDecision(
                   at: edgeIndex,
                   after: distanceMeters
               ) {
                return vertexDecision
            }
            if let fork = forkDecision(
                on: expected,
                after: distanceMeters,
                before: limit
            ) {
                return fork
            }
        }
        return nil
    }

    func courseDifference(
        for projection: RideRouteProjection,
        sample: RideRouteGuidanceSample
    ) -> Double {
        guard let accuracy = sample.horizontalAccuracyMeters,
              accuracy <= configuration.reliableHorizontalAccuracyMeters,
              sample.speedKilometersPerHour >= configuration.reliableCourseSpeedKilometersPerHour,
              let courseAccuracy = sample.courseAccuracyDegrees,
              courseAccuracy <= configuration.reliableCourseAccuracyDegrees,
              let course = sample.courseDegrees else { return .zero }
        return abs(signedAngle(from: projection.localBearingDegrees, to: course))
    }

    func hasReliableTrackingAccuracy(_ sample: RideRouteGuidanceSample) -> Bool {
        guard let accuracy = sample.horizontalAccuracyMeters else { return false }
        return accuracy >= .zero && accuracy <= configuration.reliableHorizontalAccuracyMeters
    }

    private func hasAlternativeEdge(
        at coordinate: GeographicCoordinate,
        routeDistanceMeters: Double,
        expectedEdge: RideRouteGuidanceEdge,
        excluding: Set<Int>
    ) -> Bool {
        spatialIndex.edgeIndices(
            near: coordinate,
            radiusMeters: configuration.forkProximityMeters
        ).contains { index in
            guard !excluding.contains(index) else { return false }
            let edge = edges[index]
            if edge.segmentIndex == expectedEdge.segmentIndex,
               abs(edge.edgeIndex - expectedEdge.edgeIndex) <= 1 {
                return false
            }
            let projection = edge.projection(from: coordinate)
            guard projection.distanceFromRouteMeters <= configuration.forkProximityMeters else {
                return false
            }
            return pathsDiverge(
                from: coordinate,
                routeDistanceMeters: routeDistanceMeters,
                alternativeEdge: edge,
                alternativeProjection: projection
            )
        }
    }

    private func vertexDecision(
        at edgeIndex: Int,
        after distanceMeters: Double
    ) -> RideRouteGuidanceDecision? {
        let next = edges[edgeIndex]
        let previous = edges[edgeIndex - 1]
        guard previous.segmentIndex == next.segmentIndex else { return nil }
        let delta = signedAngle(from: previous.bearingDegrees, to: next.bearingDegrees)
        let fork = hasAlternativeEdge(
            at: next.start,
            routeDistanceMeters: next.startDistanceMeters,
            expectedEdge: next,
            excluding: [previous.globalIndex, next.globalIndex]
        )
        guard fork || abs(delta) >= configuration.straightTurnThresholdDegrees else { return nil }
        return RideRouteGuidanceDecision(
            direction: turnDirection(forSignedAngle: delta),
            coordinate: next.start,
            distanceMeters: max(next.startDistanceMeters - distanceMeters, .zero),
            isFork: fork,
            identifier: "\(next.segmentIndex):\(next.edgeIndex)"
        )
    }

    private func forkDecision(
        on edge: RideRouteGuidanceEdge,
        after distanceMeters: Double,
        before limit: Double
    ) -> RideRouteGuidanceDecision? {
        let lower = max(distanceMeters, edge.startDistanceMeters)
        let upper = min(limit, edge.endDistanceMeters)
        guard upper >= lower else { return nil }
        var scanDistance = ceil(lower / Constants.forkScanSpacingMeters)
            * Constants.forkScanSpacingMeters
        while scanDistance <= upper {
            let coordinate = edge.coordinate(atDistanceAlongRouteMeters: scanDistance)
            if hasAlternativeEdge(
                at: coordinate,
                routeDistanceMeters: scanDistance,
                expectedEdge: edge,
                excluding: [edge.globalIndex]
            ) {
                return RideRouteGuidanceDecision(
                    direction: .straight,
                    coordinate: coordinate,
                    distanceMeters: max(scanDistance - distanceMeters, .zero),
                    isFork: true,
                    identifier: "\(edge.segmentIndex):\(edge.edgeIndex):\(Int(scanDistance))"
                )
            }
            scanDistance += Constants.forkScanSpacingMeters
        }
        return nil
    }

    private func pathsDiverge(
        from coordinate: GeographicCoordinate,
        routeDistanceMeters: Double,
        alternativeEdge: RideRouteGuidanceEdge,
        alternativeProjection: RideRouteProjection
    ) -> Bool {
        let lookAhead = configuration.forkDivergenceLookAheadMeters
        guard let expected = self.coordinate(
            atDistanceMeters: min(routeDistanceMeters + lookAhead, totalDistanceMeters)
        ) else { return false }
        let projectedDistance = alternativeProjection.position.distanceAlongRouteMeters
        let segmentRange = segmentRanges[alternativeEdge.segmentIndex].distanceRange
        guard segmentRange.upperBoundMeters - projectedDistance
            >= configuration.forkDivergenceMeters else { return false }
        guard let forward = self.coordinate(
            atDistanceMeters: min(
                projectedDistance + lookAhead,
                segmentRange.upperBoundMeters
            )
        ) else { return false }
        let divergence = RideRouteGeometry.distanceMeters(from: expected, to: forward)
        return divergence >= configuration.forkDivergenceMeters
            && RideRouteGeometry.distanceMeters(from: coordinate, to: expected) > .zero
    }

    private func turnDirection(forSignedAngle angle: Double) -> RideRouteGuidanceTurnDirection {
        if abs(angle) <= configuration.straightTurnThresholdDegrees { return .straight }
        return angle < .zero ? .left : .right
    }

    private func projectionPrecedes(_ lhs: RideRouteProjection, _ rhs: RideRouteProjection) -> Bool {
        if lhs.distanceFromRouteMeters == rhs.distanceFromRouteMeters {
            return lhs.position.distanceAlongRouteMeters < rhs.position.distanceAlongRouteMeters
        }
        return lhs.distanceFromRouteMeters < rhs.distanceFromRouteMeters
    }

    private func deduplicatedProjections(
        _ projections: [RideRouteProjection]
    ) -> [RideRouteProjection] {
        var occupiedBuckets = Set<ProjectionBucket>()
        var retained: [RideRouteProjection] = []
        for projection in projections {
            let bucket = ProjectionBucket(
                segmentIndex: projection.position.segmentIndex,
                distanceBucket: Int(
                    floor(
                        projection.position.distanceAlongRouteMeters
                            / Constants.projectionDeduplicationDistanceMeters
                    )
                ),
                bearingBucket: Int(floor(projection.localBearingDegrees / 45))
            )
            if occupiedBuckets.insert(bucket).inserted {
                retained.append(projection)
            }
        }
        return retained
    }

    private struct ProjectionBucket: Hashable {
        let segmentIndex: Int
        let distanceBucket: Int
        let bearingBucket: Int
    }

    private enum Constants {
        static let minimumIndicatorSeparationMeters = 10.0
        static let projectionDeduplicationDistanceMeters = 5.0
        static let forkScanSpacingMeters = 10.0
    }

}
