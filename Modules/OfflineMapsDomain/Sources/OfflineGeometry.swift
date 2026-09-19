import Foundation

public struct OfflineCoordinate: Codable, Equatable, Sendable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// A non-wrapping rectangle. Selections crossing the date line contain two rectangles.
public struct OfflineBounds: Codable, Equatable, Sendable {
    public let west: Double
    public let south: Double
    public let east: Double
    public let north: Double

    public init(west: Double, south: Double, east: Double, north: Double) {
        self.west = west
        self.south = south
        self.east = east
        self.north = north
    }

    public var isValid: Bool {
        [west, south, east, north].allSatisfy(\.isFinite)
            && west >= -180 && east <= 180 && south >= -85.051129 && north <= 85.051129
            && west < east && south < north
    }
}

public struct OfflineGeometry: Codable, Equatable, Sendable {
    public let rectangles: [OfflineBounds]

    public init(rectangles: [OfflineBounds]) {
        self.rectangles = rectangles
    }

    public var isValid: Bool { !rectangles.isEmpty && rectangles.allSatisfy(\.isValid) }
}
