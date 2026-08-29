import Foundation

public struct RideRouteSegment: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let points: [RideRoutePoint]

    public init(id: UUID = UUID(), points: [RideRoutePoint]) {
        self.id = id
        self.points = points
    }
}
