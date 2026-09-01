import RideNavigation

extension NavigationMapPolylineRole {
    var renderPriority: Int {
        switch self {
        case .trailFuture: 0
        case .planned, .trailCompleted, .approach: 1
        case .completed, .recorded: 2
        case .rejoinGuide: 3
        case .trailActive: 4
        }
    }
}
