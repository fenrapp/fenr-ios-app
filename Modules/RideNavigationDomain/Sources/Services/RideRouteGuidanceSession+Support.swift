import EnvironmentDomain
import Foundation

extension RideRouteGuidanceSession {
    struct AlternativeCandidate: Sendable {
        var projection: RideRouteProjection
        let firstCoordinate: GeographicCoordinate
        let firstObservedAt: Date
        var sampleCount: Int

        func matches(
            _ other: RideRouteProjection,
            configuration: RideRouteGuidanceConfiguration
        ) -> Bool {
            projection.position.segmentIndex == other.position.segmentIndex
                && abs(
                    projection.position.distanceAlongRouteMeters
                        - other.position.distanceAlongRouteMeters
                ) <= configuration.continuityLookAheadMeters
        }

        func elapsedSeconds(at date: Date) -> TimeInterval {
            max(date.timeIntervalSince(firstObservedAt), .zero)
        }

        func distanceMeters(to coordinate: GeographicCoordinate) -> Double {
            RideRouteGeometry.distanceMeters(from: firstCoordinate, to: coordinate)
        }
    }

    enum Constants {
        static let progressContinuityWeight = 0.05
        static let forkProgressContinuityWeight = 2.0
        static let courseWeight = 0.15
        static let minimumPlausibleAdvanceMeters = 20.0
        static let plausibleAdvanceMultiplier = 2.0
        static let plausibleAdvanceToleranceMeters = 10.0
    }
}
