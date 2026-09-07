import Foundation
import RideNavigationDomain

struct RideNavigationLibrarySnapshot: Sendable {
    var savedRoutes: [RideRoute] = []
    var persistence = RoutePersistenceRuntimeState()
    var exportRequest: GPXExportRequest?
    var shareRequest: GPXExportRequest?
    var errorMessage: String?
}
