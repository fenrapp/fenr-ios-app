import Foundation

public struct RideRoute: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let createdAt: Date
    public let updatedAt: Date
    public let segments: [RideRouteSegment]

    public init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date,
        updatedAt: Date? = nil,
        segments: [RideRouteSegment]
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.segments = segments
    }

    public var points: [RideRoutePoint] {
        segments.flatMap(\.points)
    }

    public var distanceMeters: Double {
        segments.reduce(.zero) { total, segment in
            total + RideRouteGeometry.distanceMeters(along: segment.points)
        }
    }

    public var reversed: Self {
        Self(
            id: id,
            name: name,
            createdAt: createdAt,
            updatedAt: updatedAt,
            segments: segments.reversed().map {
                RideRouteSegment(id: $0.id, points: Array($0.points.reversed()))
            }
        )
    }

    public func renamed(_ name: String, at date: Date) -> Self {
        Self(
            id: id,
            name: name,
            createdAt: createdAt,
            updatedAt: max(updatedAt, date),
            segments: segments
        )
    }
}
