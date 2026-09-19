import Foundation

public struct OfflineGeometryService: Sendable {
    private static let latitudeLimit = 85.051129
    private static let metersPerDegree = 111_000.0

    public init() {}

    public func rectangle(west: Double, south: Double, east: Double, north: Double) -> OfflineGeometry {
        guard [west, south, east, north].allSatisfy(\.isFinite), south < north, west != east else {
            return OfflineGeometry(rectangles: [])
        }
        let south = max(-Self.latitudeLimit, south)
        let north = min(Self.latitudeLimit, north)
        guard south < north else { return OfflineGeometry(rectangles: []) }
        if east - west >= 360 {
            return OfflineGeometry(rectangles: [OfflineBounds(west: -180, south: south, east: 180, north: north)])
        }
        let west = normalized(west)
        let east = normalized(east)
        let bounds = west < east
            ? [OfflineBounds(west: west, south: south, east: east, north: north)]
            : [OfflineBounds(west: west, south: south, east: 180, north: north),
               OfflineBounds(west: -180, south: south, east: east, north: north)]
        return OfflineGeometry(rectangles: bounds.filter(\.isValid))
    }

    /// Short, overlapping strips conservatively enclose each segment without bridging GPX gaps.
    public func corridor(segments: [[OfflineCoordinate]], marginMeters: Double) -> OfflineGeometry {
        guard marginMeters.isFinite, marginMeters >= 1_000, marginMeters <= 10_000 else {
            return OfflineGeometry(rectangles: [])
        }
        var rectangles: [OfflineBounds] = []
        for segment in segments {
            let segmentStart = rectangles.count
            guard segment.allSatisfy({
                $0.latitude.isFinite && $0.longitude.isFinite && abs($0.latitude) <= 90
                    && abs($0.longitude) <= 180
            }) else { return OfflineGeometry(rectangles: []) }
            if let only = segment.first, segment.count == 1 {
                rectangles += strip(from: only, to: only, margin: marginMeters).rectangles
            }
            for (start, end) in zip(segment, segment.dropFirst()) {
                let longitudeDelta = normalized(end.longitude - start.longitude)
                let length = hypot(
                    end.latitude - start.latitude,
                    longitudeDelta * cos((start.latitude + end.latitude) * .pi / 360)
                ) * Self.metersPerDegree
                let steps = max(1, Int(ceil(length / marginMeters)))
                guard steps <= 20_000, rectangles.count + steps <= 50_000 else {
                    return OfflineGeometry(rectangles: [])
                }
                for step in 0..<steps {
                    let first = Double(step) / Double(steps)
                    let last = Double(step + 1) / Double(steps)
                    let from = OfflineCoordinate(
                        latitude: start.latitude + (end.latitude - start.latitude) * first,
                        longitude: start.longitude + longitudeDelta * first
                    )
                    let destination = OfflineCoordinate(
                        latitude: start.latitude + (end.latitude - start.latitude) * last,
                        longitude: start.longitude + longitudeDelta * last
                    )
                    for bounds in strip(from: from, to: destination, margin: marginMeters).rectangles {
                        if rectangles.count > segmentStart, let previous = rectangles.last,
                           let merged = merged(previous, bounds, margin: marginMeters) {
                            rectangles[rectangles.count - 1] = merged
                        } else {
                            rectangles.append(bounds)
                        }
                    }
                }
            }
        }
        return OfflineGeometry(rectangles: rectangles)
    }

    public func availability(of requested: OfflineGeometry, within available: [OfflineGeometry]) -> OfflineCoverage {
        guard requested.isValid else { return .unavailable }
        let covers = available.flatMap(\.rectangles).filter(\.isValid)
        var intersects = false
        var complete = true
        for rectangle in requested.rectangles {
            let candidates = covers.filter {
                $0.west < rectangle.east && $0.east > rectangle.west
                    && $0.south < rectangle.north && $0.north > rectangle.south
            }
            intersects = intersects || !candidates.isEmpty
            if !isCovered(rectangle, by: candidates) { complete = false }
        }
        return complete ? .complete : intersects ? .partial : .unavailable
    }

    public func contains(_ point: OfflineCoordinate, in geometry: OfflineGeometry) -> Bool {
        geometry.rectangles.contains {
            point.latitude >= $0.south && point.latitude <= $0.north
                && normalized(point.longitude) >= $0.west && normalized(point.longitude) <= $0.east
        }
    }

    private func merged(_ first: OfflineBounds, _ second: OfflineBounds, margin: Double) -> OfflineBounds? {
        let bounds = OfflineBounds(
            west: min(first.west, second.west), south: min(first.south, second.south),
            east: max(first.east, second.east), north: max(first.north, second.north)
        )
        let latitude = max(abs(bounds.south), abs(bounds.north))
        let width = (bounds.east - bounds.west) * cos(latitude * .pi / 180) * Self.metersPerDegree
        let height = (bounds.north - bounds.south) * Self.metersPerDegree
        // Limit each union to a short strip, even for densely sampled or winding tracks.
        return max(width, height) <= margin * 3 ? bounds : nil
    }

    private func isCovered(_ rectangle: OfflineBounds, by covers: [OfflineBounds]) -> Bool {
        if covers.contains(where: {
            $0.west <= rectangle.west && $0.east >= rectangle.east
                && $0.south <= rectangle.south && $0.north >= rectangle.north
        }) { return true }
        let cuts = Set([rectangle.west, rectangle.east] + covers.flatMap {
            [max(rectangle.west, $0.west), min(rectangle.east, $0.east)]
        }).sorted()
        for (left, right) in zip(cuts, cuts.dropFirst()) where right > left {
            let spans = covers.filter { $0.west <= left && $0.east >= right }.sorted { $0.south < $1.south }
            var north = rectangle.south
            for span in spans {
                if span.south > north { break }
                north = max(north, span.north)
                if north >= rectangle.north { break }
            }
            if north < rectangle.north { return false }
        }
        return !covers.isEmpty
    }

    private func strip(from start: OfflineCoordinate, to end: OfflineCoordinate, margin: Double) -> OfflineGeometry {
        let latitudeMargin = margin / Self.metersPerDegree
        let extremeLatitude = min(Self.latitudeLimit, max(abs(start.latitude), abs(end.latitude)) + latitudeMargin)
        let longitudeMargin = latitudeMargin / cos(extremeLatitude * .pi / 180)
        return rectangle(
            west: min(start.longitude, end.longitude) - longitudeMargin,
            south: min(start.latitude, end.latitude) - latitudeMargin,
            east: max(start.longitude, end.longitude) + longitudeMargin,
            north: max(start.latitude, end.latitude) + latitudeMargin
        )
    }

    private func normalized(_ longitude: Double) -> Double {
        let remainder = (longitude + 180).truncatingRemainder(dividingBy: 360)
        return (remainder < 0 ? remainder + 360 : remainder) - 180
    }
}
