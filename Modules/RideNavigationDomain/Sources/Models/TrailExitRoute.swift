public struct TrailExitRoute: Equatable, Sendable {
    public let destination: NavigationPlace
    public let route: RoadNavigationRoute

    public init(destination: NavigationPlace, route: RoadNavigationRoute) {
        self.destination = destination
        self.route = route
    }
}
