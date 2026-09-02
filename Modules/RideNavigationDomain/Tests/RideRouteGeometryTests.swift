import EnvironmentDomain
@testable import RideNavigationDomain
import Testing

struct RideRouteGeometryTests {
    @Test("Bearing follows cardinal directions")
    func bearingFollowsCardinalDirections() throws {
        let start = try #require(GeographicCoordinate(latitudeDegrees: 41, longitudeDegrees: 2))
        let east = try #require(GeographicCoordinate(latitudeDegrees: 41, longitudeDegrees: 2.001))

        let bearing = RideRouteGeometry.bearingDegrees(from: start, to: east)

        #expect(bearing > 89)
        #expect(bearing < 91)
    }

    @Test("Near-antipodal distance stays finite")
    func nearAntipodalDistanceIsFinite() throws {
        let start = try #require(GeographicCoordinate(latitudeDegrees: -45, longitudeDegrees: 0))
        let end = try #require(
            GeographicCoordinate(latitudeDegrees: 45.000_000_01, longitudeDegrees: 179.999_999_99)
        )

        let distance = RideRouteGeometry.distanceMeters(from: start, to: end)

        #expect(distance.isFinite)
        #expect(distance > 20_015_000)
        #expect(distance < 20_016_000)
    }
}
