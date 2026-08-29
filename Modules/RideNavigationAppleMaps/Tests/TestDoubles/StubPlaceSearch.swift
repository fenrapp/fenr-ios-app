import EnvironmentDomain
import RideNavigationDomain

struct StubPlaceSearch: PlaceSearching {
    let result: [NavigationPlace]

    func search(_: String, near _: GeographicCoordinate?) async throws -> [NavigationPlace] {
        result
    }
}
