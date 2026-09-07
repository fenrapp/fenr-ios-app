import EnvironmentDomain
import Foundation
@testable import RideNavigation
import RideNavigationDomain

enum ActivityControllerTestData {
    static let startDate = Date(timeIntervalSince1970: 1_700_000_000)

    static func coordinate(index: Int) -> GeographicCoordinate {
        GeographicCoordinate(latitudeDegrees: 41 + Double(index) * 0.0002, longitudeDegrees: 2)!
    }

    static func location(index: Int, seconds: TimeInterval) -> RideNavigationLocationSnapshot {
        RideNavigationLocationSnapshot(
            coordinate: coordinate(index: index), horizontalAccuracyMeters: 5,
            courseDegrees: 0, courseAccuracyDegrees: 5, observedAt: startDate.addingTimeInterval(seconds)
        )
    }

    static func trailRoute(name: String, finishIndex: Int) -> RideRoute {
        RideRoute(
            name: name, createdAt: startDate,
            segments: [.init(points: [
                .init(coordinate: coordinate(index: 0)), .init(coordinate: coordinate(index: finishIndex))
            ])]
        )
    }

    static func destination() -> NavigationPlace {
        NavigationPlace(name: "Destination", detail: "Test destination", coordinate: coordinate(index: 5))
    }

    static func approachDestination() -> NavigationPlace {
        NavigationPlace(name: "Trail start", detail: "Test trail entry", coordinate: coordinate(index: 0))
    }

    static func approachRoute() -> RoadNavigationRoute {
        RoadNavigationRoute(
            name: "Approach", points: [coordinate(index: -3), coordinate(index: 0)],
            distanceMeters: 67, expectedTravelTime: 20, steps: []
        )
    }

    static func roadRoute() -> RoadNavigationRoute {
        RoadNavigationRoute(
            name: "Test road", points: [coordinate(index: 0), coordinate(index: 5)],
            distanceMeters: 112, expectedTravelTime: 30, steps: []
        )
    }

    static func sample(index: Int, seconds: TimeInterval) -> DeviceSpeedSample {
        DeviceSpeedSample(
            kilometersPerHour: 18,
            accuracyMetersPerSecond: 1,
            courseDegrees: 0,
            courseAccuracyDegrees: 5,
            horizontalAccuracyMeters: 5,
            coordinate: coordinate(index: index),
            observedAt: startDate.addingTimeInterval(seconds)
        )
    }
}
