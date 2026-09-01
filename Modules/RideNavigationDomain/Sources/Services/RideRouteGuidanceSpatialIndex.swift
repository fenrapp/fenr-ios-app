import EnvironmentDomain
import Foundation

struct RideRouteGuidanceEdge: Sendable {
    let globalIndex: Int
    let segmentIndex: Int
    let edgeIndex: Int
    let start: GeographicCoordinate
    let end: GeographicCoordinate
    let startDistanceMeters: Double
    let lengthMeters: Double
    let bearingDegrees: Double

    var endDistanceMeters: Double { startDistanceMeters + lengthMeters }

    func projection(from coordinate: GeographicCoordinate) -> RideRouteProjection {
        let referenceLatitude = coordinate.latitudeDegrees * .pi / 180
        let startPoint = localPoint(start, origin: coordinate, referenceLatitude: referenceLatitude)
        let endPoint = localPoint(end, origin: coordinate, referenceLatitude: referenceLatitude)
        let deltaX = endPoint.x - startPoint.x
        let deltaY = endPoint.y - startPoint.y
        let squaredLength = deltaX * deltaX + deltaY * deltaY
        let fraction = squaredLength > .zero
            ? max(.zero, min(1, -(startPoint.x * deltaX + startPoint.y * deltaY) / squaredLength))
            : .zero
        let projected = self.coordinate(atFraction: fraction)
        let distance = hypot(
            startPoint.x + fraction * deltaX,
            startPoint.y + fraction * deltaY
        )
        return RideRouteProjection(
            coordinate: projected,
            position: pathPosition(atFraction: fraction),
            distanceFromRouteMeters: distance,
            localBearingDegrees: bearingDegrees,
            confidence: confidence(forDistanceMeters: distance)
        )
    }

    func position(atDistanceAlongRouteMeters distanceMeters: Double) -> RideRoutePathPosition {
        pathPosition(atFraction: fraction(atDistanceAlongRouteMeters: distanceMeters))
    }

    func coordinate(atDistanceAlongRouteMeters distanceMeters: Double) -> GeographicCoordinate {
        coordinate(atFraction: fraction(atDistanceAlongRouteMeters: distanceMeters))
    }

    private func fraction(atDistanceAlongRouteMeters distanceMeters: Double) -> Double {
        max(.zero, min(1, (distanceMeters - startDistanceMeters) / lengthMeters))
    }

    private func pathPosition(atFraction fraction: Double) -> RideRoutePathPosition {
        RideRoutePathPosition(
            segmentIndex: segmentIndex,
            edgeIndex: edgeIndex,
            fraction: fraction,
            distanceAlongRouteMeters: startDistanceMeters + lengthMeters * fraction
        )
    }

    private func coordinate(atFraction fraction: Double) -> GeographicCoordinate {
        GeographicCoordinate(
            latitudeDegrees: start.latitudeDegrees
                + (end.latitudeDegrees - start.latitudeDegrees) * fraction,
            longitudeDegrees: start.longitudeDegrees
                + (end.longitudeDegrees - start.longitudeDegrees) * fraction
        ) ?? start
    }

    private func confidence(forDistanceMeters distanceMeters: Double) -> RideRouteProjection.Confidence {
        if distanceMeters <= 15 { return .high }
        if distanceMeters <= 30 { return .medium }
        return .low
    }

    private func localPoint(
        _ coordinate: GeographicCoordinate,
        origin: GeographicCoordinate,
        referenceLatitude: Double
    ) -> (x: Double, y: Double) {
        let longitudeDelta = (coordinate.longitudeDegrees - origin.longitudeDegrees) * .pi / 180
        let latitudeDelta = (coordinate.latitudeDegrees - origin.latitudeDegrees) * .pi / 180
        return (
            longitudeDelta * cos(referenceLatitude) * RideRouteGuidanceSpatialIndex.earthRadiusMeters,
            latitudeDelta * RideRouteGuidanceSpatialIndex.earthRadiusMeters
        )
    }
}

struct RideRouteGuidanceSpatialIndex: Sendable {
    static let earthRadiusMeters = 6_371_000.0

    struct Cell: Hashable, Sendable {
        let column: Int
        let row: Int
    }

    let origin: GeographicCoordinate
    let cellSizeMeters: Double
    let buckets: [Cell: [Int]]

    init?(
        edges: [RideRouteGuidanceEdge],
        origin: GeographicCoordinate,
        cellSizeMeters: Double,
        shouldCancel: () -> Bool = { false }
    ) {
        self.origin = origin
        self.cellSizeMeters = cellSizeMeters
        var values: [Cell: [Int]] = [:]
        for (offset, edge) in edges.enumerated() {
            if offset.isMultiple(of: Constants.cancellationCheckInterval),
               shouldCancel() {
                return nil
            }
            let start = Self.point(edge.start, origin: origin)
            let end = Self.point(edge.end, origin: origin)
            let minimumColumn = Int(floor(min(start.x, end.x) / cellSizeMeters))
            let maximumColumn = Int(floor(max(start.x, end.x) / cellSizeMeters))
            let minimumRow = Int(floor(min(start.y, end.y) / cellSizeMeters))
            let maximumRow = Int(floor(max(start.y, end.y) / cellSizeMeters))
            for column in minimumColumn...maximumColumn {
                for row in minimumRow...maximumRow {
                    values[Cell(column: column, row: row), default: []].append(edge.globalIndex)
                }
            }
        }
        buckets = values
    }

    func edgeIndices(
        near coordinate: GeographicCoordinate,
        radiusMeters: Double
    ) -> [Int] {
        let location = Self.point(coordinate, origin: origin)
        let center = Cell(
            column: Int(floor(location.x / cellSizeMeters)),
            row: Int(floor(location.y / cellSizeMeters))
        )
        let radius = max(Int(ceil(radiusMeters / cellSizeMeters)), 0) + 1
        var results = Set<Int>()
        for columnOffset in -radius...radius {
            for rowOffset in -radius...radius {
                let cell = Cell(
                    column: center.column + columnOffset,
                    row: center.row + rowOffset
                )
                results.formUnion(buckets[cell] ?? [])
            }
        }
        return results.sorted()
    }

    private static func point(
        _ coordinate: GeographicCoordinate,
        origin: GeographicCoordinate
    ) -> (x: Double, y: Double) {
        let referenceLatitude = origin.latitudeDegrees * .pi / 180
        let longitudeDelta = (coordinate.longitudeDegrees - origin.longitudeDegrees) * .pi / 180
        let latitudeDelta = (coordinate.latitudeDegrees - origin.latitudeDegrees) * .pi / 180
        return (
            longitudeDelta * cos(referenceLatitude) * Self.earthRadiusMeters,
            latitudeDelta * Self.earthRadiusMeters
        )
    }

    private enum Constants {
        static let cancellationCheckInterval = 1_024
    }
}
