import EnvironmentDomain
import Foundation
@testable import RideNavigationDomain
import Testing

struct RideRouteProgressTests {
    @Test("progress projects onto the track and aims ahead")
    func progressProjectsAndAimsAhead() throws {
        let route = route(points: [coordinate(latitude: 41), coordinate(latitude: 41.002)])
        let current = coordinate(latitude: 41.001)

        let progress = try #require(
            RideRouteGeometry.progress(
                from: current,
                along: route,
                lookAheadMeters: 35
            )
        )

        #expect(progress.distanceFromRouteMeters < 1)
        #expect(progress.remainingDistanceMeters > 100)
        #expect(progress.remainingDistanceMeters < 120)
        #expect(progress.targetCoordinate.latitudeDegrees > current.latitudeDegrees)
        #expect(abs(progress.rejoinCoordinate.latitudeDegrees - current.latitudeDegrees) < 0.000_01)
        #expect(progress.targetBearingDegrees < 1 || progress.targetBearingDegrees > 359)
    }

    @Test("progress does not snap far behind the rider")
    func progressDoesNotSnapFarBehind() throws {
        let route = route(points: [coordinate(latitude: 41), coordinate(latitude: 41.004)])
        let current = coordinate(latitude: 41.0001)

        let progress = try #require(
            RideRouteGeometry.progress(
                from: current,
                along: route,
                lookAheadMeters: 35,
                minimumDistanceAlongMeters: 200
            )
        )

        #expect(progress.distanceAlongRouteMeters >= 170)
        #expect(progress.targetCoordinate.latitudeDegrees > current.latitudeDegrees)
    }

    @Test("bearing follows cardinal directions")
    func bearingFollowsCardinalDirections() {
        let start = coordinate(latitude: 41, longitude: 2)
        let east = coordinate(latitude: 41, longitude: 2.001)

        let bearing = RideRouteGeometry.bearingDegrees(from: start, to: east)

        #expect(bearing > 89)
        #expect(bearing < 91)
    }

    @Test("near-antipodal distance stays finite")
    func nearAntipodalDistanceIsFinite() {
        let start = coordinate(latitude: -45, longitude: 0)
        let end = coordinate(latitude: 45.000_000_01, longitude: 179.999_999_99)

        let distance = RideRouteGeometry.distanceMeters(from: start, to: end)

        #expect(distance.isFinite)
        #expect(distance > 20_015_000)
        #expect(distance < 20_016_000)
    }

    @Test("crossing tracks stay close to the current route progress")
    func crossingTrackUsesCurrentProgress() throws {
        let crossing = coordinate(latitude: 41, longitude: 2)
        let route = route(points: [
            coordinate(latitude: 40.999, longitude: 1.999),
            crossing,
            coordinate(latitude: 41.001, longitude: 2.001),
            coordinate(latitude: 40.999, longitude: 2.001),
            crossing,
            coordinate(latitude: 41.001, longitude: 1.999)
        ])

        let initial = try #require(
            RideRouteGeometry.progress(from: crossing, along: route, lookAheadMeters: 35)
        )
        let later = try #require(
            RideRouteGeometry.progress(
                from: crossing,
                along: route,
                lookAheadMeters: 35,
                minimumDistanceAlongMeters: route.distanceMeters * 0.75
            )
        )

        #expect(initial.distanceAlongRouteMeters < route.distanceMeters * 0.5)
        #expect(later.distanceAlongRouteMeters > route.distanceMeters * 0.65)
    }

    private func route(points: [GeographicCoordinate]) -> RideRoute {
        let date = Date(timeIntervalSince1970: 1_000)
        return RideRoute(
            name: "Trail",
            createdAt: date,
            segments: [
                RideRouteSegment(
                    points: points.map {
                        RideRoutePoint(
                            coordinate: $0,
                            timestamp: date,
                            horizontalAccuracyMeters: 5
                        )
                    }
                )
            ]
        )
    }

    private func coordinate(
        latitude: Double,
        longitude: Double = 2
    ) -> GeographicCoordinate {
        GeographicCoordinate(latitudeDegrees: latitude, longitudeDegrees: longitude)!
    }
}
