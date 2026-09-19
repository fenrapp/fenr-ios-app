import Foundation
@testable import RideNavigationData
import Testing

@Suite("GPX text recovery")
struct GPXTextRecoveryTests {
    @Test("Recovers waypoint descriptions and track names without changing route data")
    func recoversDescriptionsAndNames() throws {
        let source = GPXTextRecoveryFixtures.descriptionsAndNames
        let parser = RideNavigationDataFixtures.makeParser()
        let recovered = try #require(parser.importRoutes(from: Data(source.utf8), fallbackName: "Imported").first)
        let escaped = source.replacingOccurrences(of: "&", with: "&amp;")
        let expected = try #require(parser.importRoutes(from: Data(escaped.utf8), fallbackName: "Imported").first)

        #expect(recovered.name == "Forest&Coast")
        #expect(recovered.segments.map(\.points) == expected.segments.map(\.points))
        #expect(recovered.createdAt == expected.createdAt)
        #expect(recovered.distanceMeters == expected.distanceMeters)
    }

    @Test("Preserves valid entities, CDATA, comments, processing instructions and quoted markup")
    func preservesXMLContent() throws {
        let data = Data(GPXTextRecoveryFixtures.preservedXMLContent.utf8)
        let parser = RideNavigationDataFixtures.makeParser()
        let routes = try parser.importRoutes(from: data, fallbackName: "Imported")

        #expect(routes.first?.name == "A & B < C \"D\" 'E' & & & F")
        let repaired = try #require(parser.recoveringText(in: data, maximumBytes: 10_000))
        let original = try #require(String(data: data, encoding: .utf8))
        let expected = original.replacingOccurrences(of: "& F", with: "&amp; F")
        #expect(repaired == Data(expected.utf8))
    }

    @Test("Valid XML needs no repair")
    func validXMLIsUnchanged() throws {
        let data = Data(#"<gpx><rte><name>A &amp; B</name><rtept lat="41" lon="2"/></rte></gpx>"#.utf8)
        let parser = RideNavigationDataFixtures.makeParser()

        #expect(parser.recoveringText(in: data, maximumBytes: 10_000) == nil)
        #expect(try parser.importRoutes(from: data, fallbackName: "Imported").first?.name == "A & B")
    }

    @Test("Rejects ambiguous entities even when another ampersand is recoverable", arguments: [
        "&unknown;", "&#0;", "&#xZZ;", "&;"
    ])
    func rejectsInvalidEntities(entity: String) {
        let data = Data(
            "<gpx><rte><name>A & B \(entity)</name><rtept lat=\"41\" lon=\"2\"/></rte></gpx>".utf8
        )
        #expect(throws: GPXRouteParserError.self) {
            try RideNavigationDataFixtures.makeParser().importRoutes(from: data, fallbackName: "Imported")
        }
    }

    @Test(
        "Does not repair attributes, measurements, declarations or broken structure",
        arguments: GPXTextRecoveryFixtures.unrecoverableDocuments
    )
    func rejectsOtherDamage(source: String) {
        #expect(throws: GPXRouteParserError.self) {
            try RideNavigationDataFixtures.makeParser().importRoutes(from: Data(source.utf8), fallbackName: "Imported")
        }
    }

    @Test("A retry discards partial routes from the first parse")
    func retryUsesFreshState() throws {
        let data = Data(
            #"""
            <gpx>
              <rte><name>First</name><rtept lat="41" lon="2"/></rte>
              <rte><name>Second & last</name><rtept lat="42" lon="3"/></rte>
            </gpx>
            """#.utf8
        )
        let routes = try RideNavigationDataFixtures.makeParser().importRoutes(from: data, fallbackName: "Imported")

        #expect(routes.map(\.name) == ["First", "Second & last"])
        #expect(routes.map { $0.points.count } == [1, 1])
    }

    @Test("Recovery preserves UTF-8 text exactly, including decomposed accents")
    func preservesUTF8Text() throws {
        let name = "Cafe\u{301} & fore\u{302}t"
        let source = "<gpx><rte><name>\(name)</name><rtept lat=\"41\" lon=\"2\"/></rte></gpx>"
        let parser = RideNavigationDataFixtures.makeParser()
        let expected = source.replacingOccurrences(of: "&", with: "&amp;")

        #expect(parser.recoveringText(in: Data(source.utf8), maximumBytes: 10_000) == Data(expected.utf8))
        #expect(try parser.importRoutes(from: Data(source.utf8), fallbackName: "Imported").first?.name == name)
    }

    @Test("Valid UTF-16 remains supported without guessing encodings during recovery")
    func preservesStrictEncodingSupport() throws {
        let source = #"<gpx><rte><name>A &amp; B</name><rtept lat="41" lon="2"/></rte></gpx>"#
        let valid = try #require(source.data(using: .utf16))
        let invalid = try #require(source.replacingOccurrences(of: "&amp;", with: "&").data(using: .utf16))
        let parser = RideNavigationDataFixtures.makeParser()

        #expect(try parser.importRoutes(from: valid, fallbackName: "Imported").first?.name == "A & B")
        #expect(parser.recoveringText(in: invalid, maximumBytes: 10_000) == nil)
        #expect(throws: GPXRouteParserError.self) {
            try parser.importRoutes(from: invalid, fallbackName: "Imported")
        }
    }

    @Test("Recovery retains point and byte limits")
    func retainsLimits() {
        let data = Data(
            #"<gpx><rte><name>A & B</name><rtept lat="41" lon="2"/><rtept lat="42" lon="3"/></rte></gpx>"#.utf8
        )
        let pointLimits = GPXRouteImportLimits(maximumFileSizeBytes: 10_000, maximumPointCount: 1)
        #expect(throws: GPXRouteParserError.tooManyPoints(maximumPoints: 1)) {
            try RideNavigationDataFixtures.makeParser(limits: pointLimits)
                .importRoutes(from: data, fallbackName: "Imported")
        }

        let byteLimits = GPXRouteImportLimits(maximumFileSizeBytes: data.count - 1, maximumPointCount: 10)
        #expect(throws: GPXRouteParserError.fileTooLarge(maximumBytes: data.count - 1)) {
            try RideNavigationDataFixtures.makeParser(limits: byteLimits)
                .importRoutes(from: data, fallbackName: "Imported")
        }
        #expect(RideNavigationDataFixtures.makeParser().recoveringText(in: data, maximumBytes: data.count) == nil)
    }
}
