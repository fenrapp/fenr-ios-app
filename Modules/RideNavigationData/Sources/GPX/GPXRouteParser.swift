import EnvironmentDomain
import Foundation
import RideNavigationDomain

public struct GPXRouteParser: GPXRouteImporting, Sendable {
    private let now: @Sendable () -> Date
    private let dateFormat: Date.ISO8601FormatStyle
    private let fallbackDateFormat: Date.ISO8601FormatStyle

    public init(
        now: @escaping @Sendable () -> Date,
        dateFormat: Date.ISO8601FormatStyle,
        fallbackDateFormat: Date.ISO8601FormatStyle
    ) {
        self.now = now
        self.dateFormat = dateFormat
        self.fallbackDateFormat = fallbackDateFormat
    }

    public func importRoutes(from data: Data, fallbackName: String) throws -> [RideRoute] {
        let delegate = GPXParserDelegate(
            fallbackName: fallbackName,
            now: now,
            dateFormat: dateFormat,
            fallbackDateFormat: fallbackDateFormat
        )
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            throw GPXRouteParserError.invalidXML(parser.parserError?.localizedDescription)
        }
        let routes = delegate.routes.filter { !$0.points.isEmpty }
        guard !routes.isEmpty else { throw GPXRouteParserError.missingTrack }
        return routes
    }
}

public enum GPXRouteParserError: Error, Equatable {
    case invalidXML(String?)
    case missingTrack
}

private final class GPXParserDelegate: NSObject, XMLParserDelegate {
    private let fallbackName: String
    private let now: @Sendable () -> Date
    private let dateFormat: Date.ISO8601FormatStyle
    private let fallbackDateFormat: Date.ISO8601FormatStyle
    private(set) var routes: [RideRoute] = []
    private var routeIndex = 0
    private var routeName: String?
    private var routeSegments: [RideRouteSegment] = []
    private var segmentPoints: [RideRoutePoint] = []
    private var pointCoordinate: GeographicCoordinate?
    private var pointElevation: Double?
    private var pointTimestamp: Date?
    private var text = ""
    private var isTrack = false
    private var isRoute = false

    init(
        fallbackName: String,
        now: @escaping @Sendable () -> Date,
        dateFormat: Date.ISO8601FormatStyle,
        fallbackDateFormat: Date.ISO8601FormatStyle
    ) {
        self.fallbackName = fallbackName
        self.now = now
        self.dateFormat = dateFormat
        self.fallbackDateFormat = fallbackDateFormat
    }

    func parser(
        _: XMLParser,
        didStartElement elementName: String,
        namespaceURI _: String?,
        qualifiedName _: String?,
        attributes attributeDict: [String: String]
    ) {
        text = ""
        switch elementName.lowercased() {
        case "trk":
            beginRoute(isTrack: true)
        case "rte":
            beginRoute(isTrack: false)
        case "trkseg":
            segmentPoints = []
        case "trkpt", "rtept":
            pointCoordinate = coordinate(attributes: attributeDict)
            pointElevation = nil
            pointTimestamp = nil
        default:
            break
        }
    }

    func parser(_: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(
        _: XMLParser,
        didEndElement elementName: String,
        namespaceURI _: String?,
        qualifiedName _: String?
    ) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch elementName.lowercased() {
        case "name" where (isTrack || isRoute) && pointCoordinate == nil:
            if routeName == nil, !value.isEmpty { routeName = value }
        case "ele" where pointCoordinate != nil:
            pointElevation = Double(value)
        case "time" where pointCoordinate != nil:
            pointTimestamp = (try? dateFormat.parse(value))
                ?? (try? fallbackDateFormat.parse(value))
        case "trkpt", "rtept":
            appendPoint()
        case "trkseg":
            closeSegment()
        case "trk", "rte":
            closeRoute()
        default:
            break
        }
        text = ""
    }

    private func beginRoute(isTrack: Bool) {
        routeIndex += 1
        routeName = nil
        routeSegments = []
        segmentPoints = []
        pointCoordinate = nil
        self.isTrack = isTrack
        isRoute = !isTrack
    }

    private func appendPoint() {
        defer {
            pointCoordinate = nil
            pointElevation = nil
            pointTimestamp = nil
        }
        guard let pointCoordinate else { return }
        segmentPoints.append(
            RideRoutePoint(
                coordinate: pointCoordinate,
                elevationMeters: pointElevation,
                timestamp: pointTimestamp
            )
        )
    }

    private func closeSegment() {
        guard !segmentPoints.isEmpty else { return }
        routeSegments.append(RideRouteSegment(points: segmentPoints))
        segmentPoints = []
    }

    private func closeRoute() {
        closeSegment()
        defer {
            isTrack = false
            isRoute = false
            routeName = nil
            routeSegments = []
        }
        guard !routeSegments.isEmpty else { return }
        let firstTimestamp = routeSegments.lazy.flatMap(\.points).compactMap(\.timestamp).first
        routes.append(
            RideRoute(
                name: resolvedName,
                createdAt: firstTimestamp ?? now(),
                segments: routeSegments
            )
        )
    }

    private var resolvedName: String {
        if let routeName, !routeName.isEmpty { return routeName }
        return routeIndex == 1 ? fallbackName : "\(fallbackName) \(routeIndex)"
    }

    private func coordinate(attributes: [String: String]) -> GeographicCoordinate? {
        guard let latitude = attributes["lat"].flatMap(Double.init),
              let longitude = attributes["lon"].flatMap(Double.init) else { return nil }
        return GeographicCoordinate(latitudeDegrees: latitude, longitudeDegrees: longitude)
    }
}
