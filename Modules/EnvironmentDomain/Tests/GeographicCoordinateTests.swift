import EnvironmentDomain
import Testing

@Suite("Geographic coordinate validation")
struct GeographicCoordinateTests {
    @Test("Accepts inclusive latitude and longitude boundaries", arguments: [
        (-90.0, -180.0),
        (-90.0, 180.0),
        (90.0, -180.0),
        (90.0, 180.0)
    ])
    func acceptsInclusiveBoundaries(latitudeDegrees: Double, longitudeDegrees: Double) {
        #expect(GeographicCoordinate(
            latitudeDegrees: latitudeDegrees,
            longitudeDegrees: longitudeDegrees
        ) != nil)
    }

    @Test("Rejects latitude outside its valid range", arguments: [
        -90.000_001,
        90.000_001
    ])
    func rejectsOutOfRangeLatitude(latitudeDegrees: Double) {
        #expect(GeographicCoordinate(
            latitudeDegrees: latitudeDegrees,
            longitudeDegrees: .zero
        ) == nil)
    }

    @Test("Rejects longitude outside its valid range", arguments: [
        -180.000_001,
        180.000_001
    ])
    func rejectsOutOfRangeLongitude(longitudeDegrees: Double) {
        #expect(GeographicCoordinate(
            latitudeDegrees: .zero,
            longitudeDegrees: longitudeDegrees
        ) == nil)
    }

    @Test("Rejects non-finite latitude", arguments: [
        Double.nan,
        .infinity,
        -.infinity
    ])
    func rejectsNonFiniteLatitude(latitudeDegrees: Double) {
        #expect(GeographicCoordinate(
            latitudeDegrees: latitudeDegrees,
            longitudeDegrees: .zero
        ) == nil)
    }

    @Test("Rejects non-finite longitude", arguments: [
        Double.nan,
        .infinity,
        -.infinity
    ])
    func rejectsNonFiniteLongitude(longitudeDegrees: Double) {
        #expect(GeographicCoordinate(
            latitudeDegrees: .zero,
            longitudeDegrees: longitudeDegrees
        ) == nil)
    }
}
