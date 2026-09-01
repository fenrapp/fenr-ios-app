import EnvironmentDomain
import Foundation
@testable import RideNavigationData
import RideNavigationDomain
import Testing

@Suite("GPX route exporter")
struct GPXRouteExporterTests {
    @Test("Escapes XML and emits only finite elevation plus timestamps")
    func exportsSafePointMetadata() throws {
        let finitePoint = RideRoutePoint(
            coordinate: GeographicCoordinate(latitudeDegrees: 41, longitudeDegrees: 2)!,
            elevationMeters: 123.5,
            timestamp: RideNavigationDataFixtures.referenceDate
        )
        let nonFinitePoint = RideRoutePoint(
            coordinate: GeographicCoordinate(latitudeDegrees: 42, longitudeDegrees: 3)!,
            elevationMeters: .infinity
        )
        let route = RideNavigationDataFixtures.makeRoute(
            name: "A&B <route> \"quoted\" 'single'",
            segments: [RideRouteSegment(points: [finitePoint, nonFinitePoint])]
        )

        let data = try GPXRouteExporter(
            dateFormat: .init(includingFractionalSeconds: true)
        ).export(route)
        let xml = try #require(String(data: data, encoding: .utf8))

        #expect(xml.contains("A&amp;B &lt;route&gt; &quot;quoted&quot; &apos;single&apos;"))
        #expect(xml.contains("<ele>123.5</ele>"))
        #expect(xml.components(separatedBy: "<ele>").count == 2)
        #expect(xml.contains("<time>2023-11-14T22:13:20.125Z</time>"))
        #expect(!xml.lowercased().contains("inf"))
        #expect(data == Data(xml.utf8))
    }
}
