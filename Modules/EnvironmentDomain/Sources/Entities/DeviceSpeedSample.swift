import Foundation

public struct DeviceSpeedSample: Equatable, Sendable {
    public let kilometersPerHour: Double
    public let accuracyMetersPerSecond: Double
    public let courseDegrees: Double?
    public let courseAccuracyDegrees: Double?
    public let altitudeMeters: Double?
    public let verticalAccuracyMeters: Double?
    public let horizontalAccuracyMeters: Double?
    public let coordinate: GeographicCoordinate?
    public let observedAt: Date

    public init(
        kilometersPerHour: Double,
        accuracyMetersPerSecond: Double,
        courseDegrees: Double? = nil,
        courseAccuracyDegrees: Double? = nil,
        altitudeMeters: Double? = nil,
        verticalAccuracyMeters: Double? = nil,
        horizontalAccuracyMeters: Double? = nil,
        coordinate: GeographicCoordinate? = nil,
        observedAt: Date
    ) {
        self.kilometersPerHour = kilometersPerHour
        self.accuracyMetersPerSecond = accuracyMetersPerSecond
        self.courseDegrees = courseDegrees
        self.courseAccuracyDegrees = courseAccuracyDegrees
        self.altitudeMeters = altitudeMeters
        self.verticalAccuracyMeters = verticalAccuracyMeters
        self.horizontalAccuracyMeters = horizontalAccuracyMeters
        self.coordinate = coordinate
        self.observedAt = observedAt
    }
}
