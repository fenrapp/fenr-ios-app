import Foundation

struct RideNavigationLibraryUpdate: Sendable {
    enum Effect: Sendable, Equatable {
        case plannedRouteReady(UUID)
        case closeCompletedRoute(UUID)
    }

    let snapshot: RideNavigationLibrarySnapshot
    let contextGeneration: UInt
    let effect: Effect?
}
