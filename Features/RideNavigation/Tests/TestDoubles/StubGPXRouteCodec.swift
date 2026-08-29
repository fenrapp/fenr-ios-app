import Foundation
import RideNavigationDomain

struct StubGPXRouteImporter: GPXRouteImporting {
    func importRoutes(from _: Data, fallbackName _: String) throws -> [RideRoute] {
        []
    }
}

struct StubGPXRouteExporter: GPXRouteExporting {
    func export(_: RideRoute) throws -> Data {
        Data()
    }
}
