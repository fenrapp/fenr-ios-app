import EnvironmentDomain
import Foundation
import RideNavigationDomain

public struct StoredRideRouteCodec: StoredRideRouteCoding {
    public init() {}

    public func encode(_ route: RideRoute) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(StoredRoute(route))
    }

    public func decode(_ data: Data) throws -> RideRoute {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let storedRoute: StoredRoute
        do {
            storedRoute = try decoder.decode(StoredRoute.self, from: data)
        } catch {
            let legacyDecoder = JSONDecoder()
            legacyDecoder.dateDecodingStrategy = .iso8601
            storedRoute = try legacyDecoder.decode(StoredRoute.self, from: data)
        }
        return try storedRoute.domain()
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

    func domain() throws -> RideRoute {
        RideRoute(
            id: id,
            name: name,
            createdAt: createdAt,
            updatedAt: updatedAt,
            segments: try segments.map { try $0.domain() }
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

    func domain() throws -> RideRouteSegment {
        RideRouteSegment(id: id, points: try points.map { try $0.domain() })
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

    func domain() throws -> RideRoutePoint {
        guard let coordinate = GeographicCoordinate(
            latitudeDegrees: latitude,
            longitudeDegrees: longitude
        ) else { throw StoredRideRouteDecodingError.invalidCoordinate }
        return RideRoutePoint(
            coordinate: coordinate,
            elevationMeters: elevationMeters,
            timestamp: timestamp,
            horizontalAccuracyMeters: horizontalAccuracyMeters
        )
    }
}

private enum StoredRideRouteDecodingError: Error {
    case invalidCoordinate
}
