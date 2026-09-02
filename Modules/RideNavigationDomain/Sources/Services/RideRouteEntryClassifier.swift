public struct RideRouteEntryClassifier: Sendable {
    public init() {}

    func classify(
        matches: [RideRouteProjection],
        courseDegrees: Double,
        configuration: RideRouteGuidanceConfiguration
    ) -> RideRouteEntryMatch {
        let closestDistance = matches.first?.distanceFromRouteMeters ?? .zero
        let tied = matches.filter {
            $0.distanceFromRouteMeters <= closestDistance + configuration.entryProjectionTieMeters
        }
        let forward = representatives(
            in: tied.filter {
                angleDifference($0.localBearingDegrees, courseDegrees)
                    <= configuration.compatibleCourseDifferenceDegrees
            },
            configuration: configuration
        )
        let reverse = representatives(
            in: tied.filter {
                angleDifference(oppositeBearing($0.localBearingDegrees), courseDegrees)
                    <= configuration.compatibleCourseDifferenceDegrees
            },
            configuration: configuration
        )
        if forward.count == 1, reverse.isEmpty {
            return .init(classification: .forward, selectedProjection: forward[0], projections: matches)
        }
        if reverse.count == 1, forward.isEmpty {
            return .init(classification: .reverse, selectedProjection: reverse[0], projections: matches)
        }
        return .init(classification: .ambiguous, selectedProjection: nil, projections: matches)
    }

    private func representatives(
        in projections: [RideRouteProjection],
        configuration: RideRouteGuidanceConfiguration
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
                    - previous.position.distanceAlongRouteMeters <= Constants.maximumOccurrenceGapMeters,
                  angleDifference(previous.localBearingDegrees, projection.localBearingDegrees)
                    <= configuration.compatibleCourseDifferenceDegrees else {
                groups.append([projection])
                continue
            }
            groups[groups.index(before: groups.endIndex)].append(projection)
        }
        return groups.compactMap { group in
            group.min { $0.distanceFromRouteMeters < $1.distanceFromRouteMeters }
        }
    }

    private func angleDifference(_ lhs: Double, _ rhs: Double) -> Double {
        abs((rhs - lhs + 540).truncatingRemainder(dividingBy: 360) - 180)
    }

    private func oppositeBearing(_ bearing: Double) -> Double {
        (bearing + 180).truncatingRemainder(dividingBy: 360)
    }

    private enum Constants {
        static let maximumOccurrenceGapMeters = 12.0
    }
}
