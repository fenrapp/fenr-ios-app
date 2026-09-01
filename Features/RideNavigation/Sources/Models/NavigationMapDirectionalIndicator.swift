public struct NavigationMapDirectionalIndicator: Equatable, Identifiable, Sendable {
    public let id: String
    public let coordinate: NavigationMapCoordinate
    public let rotationDegrees: Double

    public init(
        id: String,
        coordinate: NavigationMapCoordinate,
        rotationDegrees: Double
    ) {
        self.id = id
        self.coordinate = coordinate
        self.rotationDegrees = rotationDegrees
    }
}
