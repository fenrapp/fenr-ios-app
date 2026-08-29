import EnvironmentDomain
import Foundation

public struct RoadNavigationRoute: Equatable, Sendable {
    public let name: String
    public let points: [GeographicCoordinate]
    public let distanceMeters: Double
    public let expectedTravelTime: TimeInterval
    public let steps: [RoadNavigationStep]
    public let containsTolls: Bool
    public let containsHighways: Bool

    public init(
        name: String,
        points: [GeographicCoordinate],
        distanceMeters: Double,
        expectedTravelTime: TimeInterval,
        steps: [RoadNavigationStep],
        containsTolls: Bool = false,
        containsHighways: Bool = false
    ) {
        self.name = name
        self.points = points
        self.distanceMeters = distanceMeters
        self.expectedTravelTime = expectedTravelTime
        self.steps = steps
        self.containsTolls = containsTolls
        self.containsHighways = containsHighways
    }

    public func exportRoute(name: String, createdAt: Date) -> RideRoute? {
        guard !points.isEmpty else { return nil }
        return RideRoute(
            name: name,
            createdAt: createdAt,
            segments: [
                RideRouteSegment(
                    points: points.map { RideRoutePoint(coordinate: $0) }
                )
            ]
        )
    }
}
