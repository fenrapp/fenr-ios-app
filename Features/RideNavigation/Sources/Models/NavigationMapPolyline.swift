public struct NavigationMapPolyline: Equatable, Identifiable, Sendable {
    public let id: String
    public let points: [NavigationMapCoordinate]
    public let role: NavigationMapPolylineRole

    public init(id: String, points: [NavigationMapCoordinate], role: NavigationMapPolylineRole) {
        self.id = id
        self.points = points
        self.role = role
    }
}
