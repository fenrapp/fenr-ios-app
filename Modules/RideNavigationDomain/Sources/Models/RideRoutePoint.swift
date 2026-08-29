import EnvironmentDomain
import Foundation

public struct RideRoutePoint: Equatable, Sendable {
    public let coordinate: GeographicCoordinate
    public let elevationMeters: Double?
    public let timestamp: Date?
    public let horizontalAccuracyMeters: Double?

    public init(
        coordinate: GeographicCoordinate,
        elevationMeters: Double? = nil,
        timestamp: Date? = nil,
        horizontalAccuracyMeters: Double? = nil
    ) {
        self.coordinate = coordinate
        self.elevationMeters = elevationMeters
        self.timestamp = timestamp
        self.horizontalAccuracyMeters = horizontalAccuracyMeters
    }
}
