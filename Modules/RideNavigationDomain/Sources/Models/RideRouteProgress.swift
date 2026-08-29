import EnvironmentDomain

public struct RideRouteProgress: Equatable, Sendable {
    public let distanceFromRouteMeters: Double
    public let distanceAlongRouteMeters: Double
    public let remainingDistanceMeters: Double
    public let rejoinCoordinate: GeographicCoordinate
    public let targetCoordinate: GeographicCoordinate
    public let targetBearingDegrees: Double

    public init(
        distanceFromRouteMeters: Double,
        distanceAlongRouteMeters: Double,
        remainingDistanceMeters: Double,
        rejoinCoordinate: GeographicCoordinate,
        targetCoordinate: GeographicCoordinate,
        targetBearingDegrees: Double
    ) {
        self.distanceFromRouteMeters = distanceFromRouteMeters
        self.distanceAlongRouteMeters = distanceAlongRouteMeters
        self.remainingDistanceMeters = remainingDistanceMeters
        self.rejoinCoordinate = rejoinCoordinate
        self.targetCoordinate = targetCoordinate
        self.targetBearingDegrees = targetBearingDegrees
    }
}
