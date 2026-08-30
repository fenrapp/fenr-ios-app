import Foundation
@testable import RideNavigationData
import Testing

@Suite("Stored ride route codec")
struct StoredRideRouteCodecTests {
    @Test("Round trips fractional timestamps using seconds since 1970")
    func roundTripsFractionalTimestamps() throws {
        let route = RideNavigationDataFixtures.makeRoute(
            createdAt: RideNavigationDataFixtures.referenceDate,
            updatedAt: RideNavigationDataFixtures.laterDate
        )
        let codec = StoredRideRouteCodec()

        let data = try codec.encode(route)
        let json = try #require(String(data: data, encoding: .utf8))
        let decoded = try codec.decode(data)

        #expect(decoded == route)
        #expect(json.contains("1700000000.125"))
        #expect(json.contains("1700000100.875"))
        #expect(!json.contains("2023-"))
    }

    @Test("Decodes the legacy ISO 8601 persisted fixture")
    func decodesLegacyISO8601Fixture() throws {
        let route = try StoredRideRouteCodec().decode(StoredRideRouteFixtures.legacyRouteData)

        #expect(route.id.uuidString == "00000000-0000-0000-0000-000000000201")
        #expect(route.name == "Legacy route")
        #expect(route.createdAt == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(route.updatedAt == Date(timeIntervalSince1970: 1_700_000_100))
        #expect(route.points.count == 1)
        #expect(route.points.first?.timestamp == Date(timeIntervalSince1970: 1_700_000_010))
    }

    @Test("Rejects the whole persisted route when any coordinate is invalid")
    func rejectsInvalidPersistedCoordinate() {
        #expect(throws: (any Error).self) {
            try StoredRideRouteCodec().decode(StoredRideRouteFixtures.invalidCoordinateData)
        }
    }
}
