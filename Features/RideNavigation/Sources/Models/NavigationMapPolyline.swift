import EnvironmentDomain

public struct NavigationMapPolyline: Equatable, Identifiable, Sendable {
    public let id: String
    public let points: [GeographicCoordinate]
    public let role: NavigationMapPolylineRole

    public init(id: String, points: [GeographicCoordinate], role: NavigationMapPolylineRole) {
        self.id = id
        self.points = points
        self.role = role
    }
}
