import EnvironmentDomain
import Foundation

struct RideNavigationLocationSnapshot: Sendable {
    let coordinate: GeographicCoordinate?
    let horizontalAccuracyMeters: Double?
    let courseDegrees: Double?
    let courseAccuracyDegrees: Double?
    let altitudeMeters: Double?
    let verticalAccuracyMeters: Double?
    let observedAt: Date?

    init(
        coordinate: GeographicCoordinate? = nil,
        horizontalAccuracyMeters: Double? = nil,
        courseDegrees: Double? = nil,
        courseAccuracyDegrees: Double? = nil,
        altitudeMeters: Double? = nil,
        verticalAccuracyMeters: Double? = nil,
        observedAt: Date? = nil
    ) {
        self.coordinate = coordinate
        self.horizontalAccuracyMeters = horizontalAccuracyMeters
        self.courseDegrees = courseDegrees
        self.courseAccuracyDegrees = courseAccuracyDegrees
        self.altitudeMeters = altitudeMeters
        self.verticalAccuracyMeters = verticalAccuracyMeters
        self.observedAt = observedAt
    }
}
