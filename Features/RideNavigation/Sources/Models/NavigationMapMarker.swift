import EnvironmentDomain

public struct NavigationMapMarker: Equatable, Identifiable, Sendable {
    public let id: String
    public let coordinate: GeographicCoordinate
    public let title: String
    public let role: NavigationMapMarkerRole

    public init(
        id: String,
        coordinate: GeographicCoordinate,
        title: String,
        role: NavigationMapMarkerRole
    ) {
        self.id = id
        self.coordinate = coordinate
        self.title = title
        self.role = role
    }
}
