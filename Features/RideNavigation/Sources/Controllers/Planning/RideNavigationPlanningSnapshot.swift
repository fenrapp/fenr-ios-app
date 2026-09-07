import Foundation
import RideNavigationDomain

struct RideNavigationPlanningSnapshot: Sendable {
    var searchQuery = ""
    var searchResults: [NavigationPlace] = []
    var isSearchLoading = false
    var isPreviewSearchLoading = false
    var isSearching: Bool { isSearchLoading || isPreviewSearchLoading }
    var selectedRoute: RideRoute?
    var selectedDirection = RideRouteDirection.forward
    var roadRoute: RoadNavigationRoute?
    var roadRouteRevision = 0
    var roadRoutes: [RoadNavigationRoute] = []
    var selectedRoadRouteIndex = 0
    var selectedDestination: NavigationPlace?
    var roadNavigationPurpose: RoadNavigationPurpose?
    var trailExitPreview: TrailExitRoute?
    var trailExitPreviewRevision = 0
    var pendingExternalDestination: NavigationPlace?
    var isCalculatingRoadRoutes = false
    var isRerouting = false
    var isFindingTrailExit = false
    var errorMessage: String?

    mutating func setRoadRoute(_ route: RoadNavigationRoute?) {
        roadRoute = route
        roadRouteRevision &+= 1
    }

    mutating func setTrailExit(_ exit: TrailExitRoute?) {
        trailExitPreview = exit
        trailExitPreviewRevision &+= 1
    }
}
