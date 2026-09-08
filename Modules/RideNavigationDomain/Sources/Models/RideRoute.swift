import Foundation

public struct RideRoute: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let createdAt: Date
    public let updatedAt: Date
    public let segments: [RideRouteSegment]
    public let distanceMeters: Double

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
        distanceMeters = segments.reduce(.zero) { total, segment in
            total + RideRouteGeometry.distanceMeters(along: segment.points)
        }
    }

    init(
        id: UUID,
        name: String,
        dates: (createdAt: Date, updatedAt: Date?),
        segments: [RideRouteSegment],
        recordedDistanceMeters: Double
    ) {
        self.id = id
        self.name = name
        createdAt = dates.createdAt
        updatedAt = dates.updatedAt ?? dates.createdAt
        self.segments = segments
        distanceMeters = recordedDistanceMeters
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.createdAt == rhs.createdAt
            && lhs.updatedAt == rhs.updatedAt && lhs.segments == rhs.segments
    }

    public var points: [RideRoutePoint] {
        segments.flatMap(\.points)
    }

    private init(original: Self, name: String, updatedAt: Date, segments: [RideRouteSegment]) {
        id = original.id
        self.name = name
        createdAt = original.createdAt
        self.updatedAt = updatedAt
        self.segments = segments
        distanceMeters = original.distanceMeters
    }

    public var reversed: Self {
        Self(
            original: self,
            name: name,
            updatedAt: updatedAt,
            segments: segments.reversed().map {
                RideRouteSegment(id: $0.id, points: Array($0.points.reversed()))
            }
        )
    }

    public func renamed(_ name: String, at date: Date) -> Self {
        Self(
            original: self,
            name: name,
            updatedAt: max(updatedAt, date),
            segments: segments
        )
    }
}
