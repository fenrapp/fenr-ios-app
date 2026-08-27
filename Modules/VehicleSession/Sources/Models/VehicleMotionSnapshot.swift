import EnvironmentDomain
import Foundation

public enum VehicleMotionAvailability: Equatable, Sendable {
    case unavailable
    case uncalibrated
    case available
    case stale
}

public enum VehicleMotionHeadingSource: Equatable, Sendable {
    case unavailable
    case gpsCourse
    case magnetic
}

public struct VehicleMotionSnapshot: Equatable, Sendable {
    public let rollDegrees: Double?
    public let pitchDegrees: Double?
    public let headingDegrees: Double?
    public let altitudeMeters: Double?
    public let coordinate: GeographicCoordinate?
    public let headingSource: VehicleMotionHeadingSource
    public let availability: VehicleMotionAvailability
    public let observedAt: Date?

    public init(
        rollDegrees: Double? = nil,
        pitchDegrees: Double? = nil,
        headingDegrees: Double? = nil,
        altitudeMeters: Double? = nil,
        coordinate: GeographicCoordinate? = nil,
        headingSource: VehicleMotionHeadingSource = .unavailable,
        availability: VehicleMotionAvailability = .unavailable,
        observedAt: Date? = nil
    ) {
        self.rollDegrees = rollDegrees
        self.pitchDegrees = pitchDegrees
        self.headingDegrees = headingDegrees
        self.altitudeMeters = altitudeMeters
        self.coordinate = coordinate
        self.headingSource = headingSource
        self.availability = availability
        self.observedAt = observedAt
    }
}
