import EnvironmentDomain
import Foundation
@testable import RideNavigationDomain
import Testing

enum RideRouteGuidanceTestFactory {
    static let date = Date(timeIntervalSince1970: 1_000)

    static func coordinate(
        latitude: Double,
        longitude: Double = 2
    ) -> GeographicCoordinate {
        GeographicCoordinate(latitudeDegrees: latitude, longitudeDegrees: longitude)!
    }

    static func route(
        segments: [[GeographicCoordinate]],
        name: String = "Trail"
    ) -> RideRoute {
        RideRoute(
            name: name,
            createdAt: date,
            segments: segments.map { coordinates in
                RideRouteSegment(
                    points: coordinates.map {
                        RideRoutePoint(
                            coordinate: $0,
                            timestamp: date,
                            horizontalAccuracyMeters: 5
                        )
                    }
                )
            }
        )
    }

    static func sample(
        _ coordinate: GeographicCoordinate,
        seconds: TimeInterval = .zero,
        courseDegrees: Double? = 0,
        courseAccuracyDegrees: Double? = 5,
        horizontalAccuracyMeters: Double? = 5,
        speedKilometersPerHour: Double = 20
    ) -> RideRouteGuidanceSample {
        RideRouteGuidanceSample(
            coordinate: coordinate,
            horizontalAccuracyMeters: horizontalAccuracyMeters,
            courseDegrees: courseDegrees,
            courseAccuracyDegrees: courseAccuracyDegrees,
            speedKilometersPerHour: speedKilometersPerHour,
            observedAt: date.addingTimeInterval(seconds)
        )
    }

    static func plan(
        for route: RideRoute,
        direction: RideRouteDirection = .forward,
        configuration: RideRouteGuidanceConfiguration = .standard
    ) async throws -> RideRouteGuidancePlan {
        try #require(
            await DefaultRideRouteGuidancePlanner(
                entryClassifier: RideRouteEntryClassifier()
            ).makePlan(
                for: route,
                direction: direction,
                configuration: configuration
            )
        )
    }
}
