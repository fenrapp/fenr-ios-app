import EnvironmentDomain
import Foundation
import RideNavigationDomain

struct StubExternalMapLinkResolver: ExternalMapLinkResolving {
    var destination = NavigationPlace(
        name: "Shared destination",
        detail: "Map link",
        coordinate: GeographicCoordinate(latitudeDegrees: 41.0, longitudeDegrees: 2.0)!
    )

    func destination(from _: URL) async throws -> NavigationPlace {
        destination
    }
}
