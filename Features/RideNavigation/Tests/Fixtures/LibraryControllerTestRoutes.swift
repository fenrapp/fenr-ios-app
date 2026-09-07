import EnvironmentDomain
import Foundation
import RideNavigationDomain

enum LibraryControllerTestRoutes {
    static func route(name: String) -> RideRoute {
        RideRoute(
            name: name,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            segments: [
                RideRouteSegment(points: [
                    RideRoutePoint(coordinate: GeographicCoordinate(latitudeDegrees: 41, longitudeDegrees: 2)!),
                    RideRoutePoint(coordinate: GeographicCoordinate(latitudeDegrees: 41.001, longitudeDegrees: 2.001)!)
                ])
            ]
        )
    }
}
