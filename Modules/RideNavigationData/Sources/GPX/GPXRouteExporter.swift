import Foundation
import RideNavigationDomain

public struct GPXRouteExporter: GPXRouteExporting, Sendable {
    private let dateFormat: Date.ISO8601FormatStyle

    public init(dateFormat: Date.ISO8601FormatStyle) {
        self.dateFormat = dateFormat
    }

    public func export(_ route: RideRoute) throws -> Data {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        xml += "<gpx version=\"1.1\" creator=\"FENR\" xmlns=\"http://www.topografix.com/GPX/1/1\">\n"
        let timestamp = route.createdAt.formatted(dateFormat)
        xml += "  <metadata><name>\(escape(route.name))</name><time>\(timestamp)</time></metadata>\n"
        xml += "  <trk>\n    <name>\(escape(route.name))</name>\n"
        for segment in route.segments where !segment.points.isEmpty {
            xml += "    <trkseg>\n"
            for point in segment.points {
                let latitude = point.coordinate.latitudeDegrees
                let longitude = point.coordinate.longitudeDegrees
                xml += "      <trkpt lat=\"\(latitude)\" lon=\"\(longitude)\">"
                if let elevation = point.elevationMeters, elevation.isFinite {
                    xml += "<ele>\(elevation)</ele>"
                }
                if let timestamp = point.timestamp {
                    xml += "<time>\(timestamp.formatted(dateFormat))</time>"
                }
                xml += "</trkpt>\n"
            }
            xml += "    </trkseg>\n"
        }
        xml += "  </trk>\n</gpx>\n"
        guard let data = xml.data(using: .utf8) else { throw GPXRouteExporterError.encodingFailed }
        return data
    }

    private func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

public enum GPXRouteExporterError: Error {
    case encodingFailed
}
