import Foundation
import RideNavigationDomain

struct FixedGPXRouteImporter: GPXRouteImporting {
    let routes: [RideRoute]

    func importRoutes(from _: Data, fallbackName _: String) throws -> [RideRoute] {
        routes
    }
}
