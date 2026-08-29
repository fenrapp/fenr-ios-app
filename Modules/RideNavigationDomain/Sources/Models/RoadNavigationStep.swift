import EnvironmentDomain
import Foundation

public struct RoadNavigationStep: Equatable, Sendable {
    public let instruction: String
    public let distanceMeters: Double
    public let points: [GeographicCoordinate]

    public init(
        instruction: String,
        distanceMeters: Double,
        points: [GeographicCoordinate] = []
    ) {
        self.instruction = instruction
        self.distanceMeters = distanceMeters
        self.points = points
    }
}
