public struct OfflineMapViewport: Equatable, Sendable {
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
}
