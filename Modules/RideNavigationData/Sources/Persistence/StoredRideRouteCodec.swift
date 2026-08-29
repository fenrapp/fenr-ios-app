import EnvironmentDomain
import Foundation
import RideNavigationDomain

public struct StoredRideRouteCodec: Sendable {
    public init() {}

    public func encode(_ route: RideRoute) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(StoredRoute(route))
    }

    public func decode(_ data: Data) throws -> RideRoute {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(StoredRoute.self, from: data).domain
    }
}

private struct StoredRoute: Codable {
    let id: UUID
    let name: String
    let createdAt: Date
    let updatedAt: Date
    let segments: [StoredSegment]

    init(_ route: RideRoute) {
        id = route.id
        name = route.name
        createdAt = route.createdAt
        updatedAt = route.updatedAt
        segments = route.segments.map(StoredSegment.init)
    }

    var domain: RideRoute {
        RideRoute(
            id: id,
            name: name,
            createdAt: createdAt,
            updatedAt: updatedAt,
            segments: segments.map(\.domain)
        )
    }
}

private struct StoredSegment: Codable {
    let id: UUID
    let points: [StoredPoint]

    init(_ segment: RideRouteSegment) {
        id = segment.id
        points = segment.points.map(StoredPoint.init)
    }

    var domain: RideRouteSegment {
        RideRouteSegment(id: id, points: points.compactMap(\.domain))
    }
}

private struct StoredPoint: Codable {
    let latitude: Double
    let longitude: Double
    let elevationMeters: Double?
    let timestamp: Date?
    let horizontalAccuracyMeters: Double?

    init(_ point: RideRoutePoint) {
        latitude = point.coordinate.latitudeDegrees
        longitude = point.coordinate.longitudeDegrees
        elevationMeters = point.elevationMeters
        timestamp = point.timestamp
        horizontalAccuracyMeters = point.horizontalAccuracyMeters
    }

    var domain: RideRoutePoint? {
        guard let coordinate = GeographicCoordinate(
            latitudeDegrees: latitude,
            longitudeDegrees: longitude
        ) else { return nil }
        return RideRoutePoint(
            coordinate: coordinate,
            elevationMeters: elevationMeters,
            timestamp: timestamp,
            horizontalAccuracyMeters: horizontalAccuracyMeters
        )
    }
}
