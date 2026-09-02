import EnvironmentDomain
import Foundation

struct RideRouteAlternativeCandidate: Sendable {
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
