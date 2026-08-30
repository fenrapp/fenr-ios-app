import Foundation
@testable import RideNavigationData
import Testing

@Suite("GPX route parser")
struct GPXRouteParserTests {
    @Test("Imports multiple tracks, routes, and track segments in source order")
    func importsMultipleRoutesAndSegments() throws {
        let data = Data(
            #"""
            <gpx version="1.1">
              <metadata><name>Metadata name</name></metadata>
              <trk>
                <name>First track</name>
                <trkseg><trkpt lat="41" lon="2"/></trkseg>
                <trkseg><trkpt lat="42" lon="3"/></trkseg>
              </trk>
              <rte><name>Named route</name><rtept lat="43" lon="4"/></rte>
              <trk><trkseg><trkpt lat="44" lon="5"/></trkseg></trk>
            </gpx>
            """#.utf8
        )

        let routes = try RideNavigationDataFixtures.makeParser()
            .importRoutes(from: data, fallbackName: "Imported")

        #expect(routes.map(\.name) == ["First track", "Named route", "Imported 3"])
        #expect(routes.map(\.segments.count) == [2, 1, 1])
        #expect(routes.map { $0.points.count } == [2, 1, 1])
    }

    @Test("Resolves created date from metadata, point timestamp, then injected now")
    func resolvesCreatedDatePrecedence() throws {
        let metadataDate = "2023-11-14T22:13:20.125Z"
        let pointDate = "2023-11-14T22:15:00.875Z"
        let data = Data(
            """
            <gpx version="1.1">
              <metadata><time>\(metadataDate)</time></metadata>
              <trk><trkseg><trkpt lat="41" lon="2"><time>\(pointDate)</time></trkpt></trkseg></trk>
              <rte><rtept lat="42" lon="3"><time>\(pointDate)</time></rtept></rte>
            </gpx>
            """.utf8
        )

        let routes = try RideNavigationDataFixtures.makeParser()
            .importRoutes(from: data, fallbackName: "Imported")
        #expect(routes.map(\.createdAt) == [
            RideNavigationDataFixtures.referenceDate,
            RideNavigationDataFixtures.referenceDate
        ])

        let pointOnly = Data(
            "<gpx><trk><trkseg><trkpt lat=\"41\" lon=\"2\"><time>\(pointDate)</time></trkpt></trkseg></trk></gpx>".utf8
        )
        #expect(try RideNavigationDataFixtures.makeParser()
            .importRoutes(from: pointOnly, fallbackName: "Imported").first?.createdAt
            == RideNavigationDataFixtures.laterDate)

        let noTimes = Data("<gpx><rte><rtept lat=\"41\" lon=\"2\"/></rte></gpx>".utf8)
        #expect(try RideNavigationDataFixtures.makeParser()
            .importRoutes(from: noTimes, fallbackName: "Imported").first?.createdAt
            == RideNavigationDataFixtures.laterDate)
    }

    @Test("Skips invalid coordinates and rejects documents without a valid point")
    func validatesCoordinatesAndTracks() throws {
        let mixed = Data(
            #"""
            <gpx><trk><trkseg>
              <trkpt lat="91" lon="2"/>
              <trkpt lon="2"/>
              <trkpt lat="41" lon="2"><ele>Infinity</ele></trkpt>
            </trkseg></trk></gpx>
            """#.utf8
        )
        let routes = try RideNavigationDataFixtures.makeParser()
            .importRoutes(from: mixed, fallbackName: "Imported")
        #expect(routes.first?.points.count == 1)
        #expect(routes.first?.points.first?.elevationMeters == nil)

        let invalidOnly = Data("<gpx><rte><rtept lat=\"NaN\" lon=\"2\"/></rte></gpx>".utf8)
        #expect(throws: GPXRouteParserError.missingTrack) {
            try RideNavigationDataFixtures.makeParser()
                .importRoutes(from: invalidOnly, fallbackName: "Imported")
        }

        #expect(throws: GPXRouteParserError.self) {
            try RideNavigationDataFixtures.makeParser()
                .importRoutes(from: Data("<gpx>".utf8), fallbackName: "Imported")
        }
    }

    @Test("Rejects data before parsing when the byte limit is exceeded")
    func enforcesByteLimit() {
        let data = Data("<gpx><rte><rtept lat=\"41\" lon=\"2\"/></rte></gpx>".utf8)
        let limits = GPXRouteImportLimits(
            maximumFileSizeBytes: data.count - 1,
            maximumPointCount: 10
        )

        #expect(throws: GPXRouteParserError.fileTooLarge(maximumBytes: data.count - 1)) {
            try RideNavigationDataFixtures.makeParser(limits: limits)
                .importRoutes(from: data, fallbackName: "Imported")
        }
    }

    @Test("Aborts deterministically when the point limit is exceeded")
    func enforcesPointLimit() {
        let data = Data(
            "<gpx><rte><rtept lat=\"41\" lon=\"2\"/><rtept lat=\"42\" lon=\"3\"/></rte></gpx>".utf8
        )
        let limits = GPXRouteImportLimits(maximumFileSizeBytes: data.count, maximumPointCount: 1)

        #expect(throws: GPXRouteParserError.tooManyPoints(maximumPoints: 1)) {
            try RideNavigationDataFixtures.makeParser(limits: limits)
                .importRoutes(from: data, fallbackName: "Imported")
        }
    }

    @Test("Does not resolve external entity declarations")
    func doesNotResolveExternalEntities() throws {
        let data = Data(
            #"""
            <?xml version="1.0"?>
            <!DOCTYPE gpx [<!ENTITY external SYSTEM "file:///etc/passwd">]>
            <gpx><metadata><name>&external;</name></metadata><rte><rtept lat="41" lon="2"/></rte></gpx>
            """#.utf8
        )

        let routes = try RideNavigationDataFixtures.makeParser()
            .importRoutes(from: data, fallbackName: "Imported")

        #expect(routes.first?.name == "Imported")
        #expect(routes.first?.points.count == 1)
    }
}
