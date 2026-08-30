import Foundation
import RideNavigationDomain

struct StubGPXRouteImporter: GPXRouteImporting {
    func importRoutes(from _: Data, fallbackName _: String) throws -> [RideRoute] {
        []
    }
}

struct StubGPXRouteExporter: GPXRouteExporting {
    static let exportedData = Data("stub-gpx".utf8)

    func export(_: RideRoute) throws -> Data {
        Self.exportedData
    }
}
