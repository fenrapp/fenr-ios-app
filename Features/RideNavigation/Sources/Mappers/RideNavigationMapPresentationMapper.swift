import EnvironmentDomain

public struct RideNavigationMapPresentationMapper: Sendable {
    public init() {}

    func coordinate(_ coordinate: GeographicCoordinate) -> NavigationMapCoordinate {
        // GeographicCoordinate has already validated these values at the domain boundary.
        NavigationMapCoordinate(
            latitudeDegrees: coordinate.latitudeDegrees,
            longitudeDegrees: coordinate.longitudeDegrees
        )!
    }

    func coordinates(_ coordinates: [GeographicCoordinate]) -> [NavigationMapCoordinate] {
        coordinates.map(coordinate)
    }
}
