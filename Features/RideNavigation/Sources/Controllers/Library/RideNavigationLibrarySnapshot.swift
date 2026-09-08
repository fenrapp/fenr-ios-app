import Foundation
import RideNavigationDomain

struct RideNavigationLibrarySnapshot: Sendable {
    var savedRoutes: [RideRouteSummary] = [] {
        didSet { if oldValue != savedRoutes { revision &+= 1 } }
    }
    private(set) var revision: UInt64 = 0
    var persistence = RoutePersistenceRuntimeState()
    var exportRequest: GPXExportRequest?
    var shareRequest: GPXExportRequest?
    var errorMessage: String?
}
