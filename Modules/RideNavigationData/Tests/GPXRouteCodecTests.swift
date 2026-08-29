import Foundation
@testable import RideNavigationData
import RideNavigationDomain
import Testing

struct GPXRouteCodecTests {
    @Test
    func exportsAndImportsWikilocCompatibleGPXTrackSegments() throws {
        let format = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let route = RideRoute(
            name: "Forest & Coast",
            createdAt: date,
            segments: [
                RideRouteSegment(points: [point(41, 2, date), point(41.001, 2.001, date)]),
                RideRouteSegment(points: [point(41.002, 2.002, date)])
            ]
        )

        let data = try GPXRouteExporter(dateFormat: format).export(route)
        let xml = try #require(String(data: data, encoding: .utf8))
        let imported = try GPXRouteParser(
            now: { date },
            dateFormat: format,
            fallbackDateFormat: .init()
        )
            .importRoutes(from: data, fallbackName: "Fallback")
        let decoded = try #require(imported.first)

        #expect(xml.contains("version=\"1.1\""))
        #expect(xml.contains("<name>Forest &amp; Coast</name>"))
        #expect(decoded.name == route.name)
        #expect(decoded.segments.count == 2)
        #expect(decoded.points.count == 3)
    }

    @Test
    func importsRoutePointFilesAsATrack() throws {
        let data = Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" xmlns="http://www.topografix.com/GPX/1/1">
          <rte><name>Trail</name><rtept lat="41.0" lon="2.0"/><rtept lat="41.1" lon="2.1"/></rte>
        </gpx>
        """.utf8)
        let routes = try GPXRouteParser(
            now: { Date(timeIntervalSince1970: 1) },
            dateFormat: .init(includingFractionalSeconds: true),
            fallbackDateFormat: .init()
        ).importRoutes(from: data, fallbackName: "Fallback")

        #expect(routes.first?.name == "Trail")
        #expect(routes.first?.points.count == 2)
    }

    private func point(_ latitude: Double, _ longitude: Double, _ date: Date) -> RideRoutePoint {
        RideRoutePoint(
            coordinate: .init(latitudeDegrees: latitude, longitudeDegrees: longitude)!,
            elevationMeters: 100,
            timestamp: date,
            horizontalAccuracyMeters: 5
        )
    }
}
