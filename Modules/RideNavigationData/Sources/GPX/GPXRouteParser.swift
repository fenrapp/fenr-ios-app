import EnvironmentDomain
import Foundation
import RideNavigationDomain

public struct GPXRouteParser: GPXRouteImporting, Sendable {
    private let now: @Sendable () -> Date
    private let dateFormat: Date.ISO8601FormatStyle
    private let fallbackDateFormat: Date.ISO8601FormatStyle
    private let limits: GPXRouteImportLimits

    public init(
        now: @escaping @Sendable () -> Date,
        dateFormat: Date.ISO8601FormatStyle,
        fallbackDateFormat: Date.ISO8601FormatStyle,
        limits: GPXRouteImportLimits
    ) {
        self.now = now
        self.dateFormat = dateFormat
        self.fallbackDateFormat = fallbackDateFormat
        self.limits = limits
    }

    public func importRoutes(from data: Data, fallbackName: String) throws -> [RideRoute] {
        guard data.count <= limits.maximumFileSizeBytes else {
            throw GPXRouteParserError.fileTooLarge(maximumBytes: limits.maximumFileSizeBytes)
        }
        let delegate = GPXParserDelegate(
            fallbackName: fallbackName,
            now: now,
            dateFormat: dateFormat,
            fallbackDateFormat: fallbackDateFormat,
            maximumPointCount: limits.maximumPointCount
        )
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        let didParse = parser.parse()
        if let error = delegate.error {
            throw error
        }
        guard didParse else {
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
    case fileTooLarge(maximumBytes: Int)
    case tooManyPoints(maximumPoints: Int)
}

private final class GPXParserDelegate: NSObject, XMLParserDelegate {
    private let fallbackName: String
    private let now: @Sendable () -> Date
    private let dateFormat: Date.ISO8601FormatStyle
    private let fallbackDateFormat: Date.ISO8601FormatStyle
    private let maximumPointCount: Int
    private(set) var routes: [RideRoute] = []
    private(set) var error: GPXRouteParserError?
    private var elementStack: [String] = []
    private var routeIndex = 0
    private var pointCount = 0
    private var metadataName: String?
    private var metadataTime: Date?
    private var routeName: String?
    private var routeSegments: [RideRouteSegment] = []
    private var segmentPoints: [RideRoutePoint] = []
    private var pointCoordinate: GeographicCoordinate?
    private var pointElevation: Double?
    private var pointTimestamp: Date?
    private var text = ""

    init(
        fallbackName: String,
        now: @escaping @Sendable () -> Date,
        dateFormat: Date.ISO8601FormatStyle,
        fallbackDateFormat: Date.ISO8601FormatStyle,
        maximumPointCount: Int
    ) {
        self.fallbackName = fallbackName
        self.now = now
        self.dateFormat = dateFormat
        self.fallbackDateFormat = fallbackDateFormat
        self.maximumPointCount = maximumPointCount
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI _: String?,
        qualifiedName _: String?,
        attributes attributeDict: [String: String]
    ) {
        text = ""
        let normalizedName = elementName.lowercased()
        let parent = elementStack.last
        elementStack.append(normalizedName)
        switch normalizedName {
        case "trk":
            beginRoute()
        case "rte":
            beginRoute()
        case "trkseg" where parent == "trk":
            segmentPoints = []
        case "trkpt", "rtept":
            pointCount += 1
            guard pointCount <= maximumPointCount else {
                error = .tooManyPoints(maximumPoints: maximumPointCount)
                parser.abortParsing()
                return
            }
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
        let normalizedName = elementName.lowercased()
        let parent = elementStack.dropLast().last
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch normalizedName {
        case "name" where parent == "metadata":
            if metadataName == nil, !value.isEmpty { metadataName = value }
        case "time" where parent == "metadata":
            metadataTime = parseDate(value)
        case "name" where parent == "trk" || parent == "rte":
            if routeName == nil, !value.isEmpty { routeName = value }
        case "ele" where parent == "trkpt" || parent == "rtept":
            if let elevation = Double(value), elevation.isFinite {
                pointElevation = elevation
            }
        case "time" where parent == "trkpt" || parent == "rtept":
            pointTimestamp = parseDate(value)
        case "trkpt", "rtept":
            appendPoint()
        case "trkseg":
            closeSegment()
        case "trk", "rte":
            closeRoute()
        default:
            break
        }
        if elementStack.last == normalizedName {
            elementStack.removeLast()
        }
        text = ""
    }

    private func beginRoute() {
        routeIndex += 1
        routeName = nil
        routeSegments = []
        segmentPoints = []
        pointCoordinate = nil
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
            routeName = nil
            routeSegments = []
        }
        guard !routeSegments.isEmpty else { return }
        let firstTimestamp = routeSegments.lazy.flatMap(\.points).compactMap(\.timestamp).first
        routes.append(
            RideRoute(
                name: resolvedName,
                createdAt: metadataTime ?? firstTimestamp ?? now(),
                segments: routeSegments
            )
        )
    }

    private var resolvedName: String {
        if let routeName, !routeName.isEmpty { return routeName }
        if routeIndex == 1, let metadataName, !metadataName.isEmpty { return metadataName }
        return routeIndex == 1 ? fallbackName : "\(fallbackName) \(routeIndex)"
    }

    private func parseDate(_ value: String) -> Date? {
        (try? dateFormat.parse(value)) ?? (try? fallbackDateFormat.parse(value))
    }

    private func coordinate(attributes: [String: String]) -> GeographicCoordinate? {
        guard let latitude = attributes["lat"].flatMap(Double.init),
              let longitude = attributes["lon"].flatMap(Double.init) else { return nil }
        return GeographicCoordinate(latitudeDegrees: latitude, longitudeDegrees: longitude)
    }
}
