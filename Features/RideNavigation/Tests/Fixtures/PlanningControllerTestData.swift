import EnvironmentDomain
import Foundation
import RideNavigationDomain

enum PlanningControllerTestData {
    static let origin = GeographicCoordinate(latitudeDegrees: 41, longitudeDegrees: 2)!

    static func place(name: String) -> NavigationPlace {
        NavigationPlace(
            name: name,
            detail: "Test destination",
            coordinate: GeographicCoordinate(latitudeDegrees: 41.01, longitudeDegrees: 2.01)!
        )
    }

    static func roadRoute(name: String) -> RoadNavigationRoute {
        RoadNavigationRoute(
            name: name,
            points: [origin, place(name: "Destination").coordinate],
            distanceMeters: 1_000,
            expectedTravelTime: 120,
            steps: []
        )
    }

    static func trailExit(name: String) -> TrailExitRoute {
        TrailExitRoute(destination: place(name: name), route: roadRoute(name: name))
    }
}
