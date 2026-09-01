public struct NavigationMapPolyline: Equatable, Identifiable, Sendable {
    public let id: String
    public let points: [NavigationMapCoordinate]
    public let role: NavigationMapPolylineRole
    public let revision: Int

    public init(
        id: String,
        points: [NavigationMapCoordinate],
        role: NavigationMapPolylineRole,
        revision: Int? = nil
    ) {
        self.id = id
        self.points = points
        self.role = role
        self.revision = revision ?? Self.geometryRevision(points)
    }

    private static func geometryRevision(_ points: [NavigationMapCoordinate]) -> Int {
        var hasher = Hasher()
        hasher.combine(points.count)
        for point in points {
            hasher.combine(point.latitudeDegrees.bitPattern)
            hasher.combine(point.longitudeDegrees.bitPattern)
        }
        return hasher.finalize()
    }
}
