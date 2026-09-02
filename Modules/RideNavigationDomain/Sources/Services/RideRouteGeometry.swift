import EnvironmentDomain
import Foundation

public enum RideRouteGeometry {
    public static func distanceMeters(
        from start: GeographicCoordinate,
        to end: GeographicCoordinate
    ) -> Double {
        let latitude1 = start.latitudeDegrees * .pi / 180
        let latitude2 = end.latitudeDegrees * .pi / 180
        let latitudeDelta = (end.latitudeDegrees - start.latitudeDegrees) * .pi / 180
        let longitudeDelta = (end.longitudeDegrees - start.longitudeDegrees) * .pi / 180
        let value = sin(latitudeDelta / 2) * sin(latitudeDelta / 2)
            + cos(latitude1) * cos(latitude2)
            * sin(longitudeDelta / 2) * sin(longitudeDelta / 2)
        let clampedValue = max(.zero, min(1, value))
        return Constants.earthRadiusMeters * 2 * atan2(
            sqrt(clampedValue),
            sqrt(1 - clampedValue)
        )
    }

    public static func distanceMeters(along points: [RideRoutePoint]) -> Double {
        zip(points, points.dropFirst()).reduce(.zero) { total, pair in
            total + distanceMeters(from: pair.0.coordinate, to: pair.1.coordinate)
        }
    }

    public static func bearingDegrees(
        from start: GeographicCoordinate,
        to end: GeographicCoordinate
    ) -> Double {
        let latitude1 = start.latitudeDegrees * .pi / 180
        let latitude2 = end.latitudeDegrees * .pi / 180
        let longitudeDelta = (end.longitudeDegrees - start.longitudeDegrees) * .pi / 180
        let yValue = sin(longitudeDelta) * cos(latitude2)
        let xValue = cos(latitude1) * sin(latitude2)
            - sin(latitude1) * cos(latitude2) * cos(longitudeDelta)
        let degrees = atan2(yValue, xValue) * 180 / .pi
        return (degrees + 360).truncatingRemainder(dividingBy: 360)
    }

    public static func closestDistanceMeters(
        from coordinate: GeographicCoordinate,
        to points: [GeographicCoordinate]
    ) -> Double? {
        guard let first = points.first else { return nil }
        guard points.count > 1 else { return distanceMeters(from: coordinate, to: first) }
        return zip(points, points.dropFirst()).map { pair in
            distanceToSegmentMeters(coordinate, start: pair.0, end: pair.1)
        }.min()
    }

    private static func distanceToSegmentMeters(
        _ coordinate: GeographicCoordinate,
        start: GeographicCoordinate,
        end: GeographicCoordinate
    ) -> Double {
        let referenceLatitude = coordinate.latitudeDegrees * .pi / 180
        let startPoint = localPoint(start, origin: coordinate, referenceLatitude: referenceLatitude)
        let endPoint = localPoint(end, origin: coordinate, referenceLatitude: referenceLatitude)
        let deltaX = endPoint.x - startPoint.x
        let deltaY = endPoint.y - startPoint.y
        let squaredLength = deltaX * deltaX + deltaY * deltaY
        guard squaredLength > .zero else {
            return hypot(startPoint.x, startPoint.y)
        }
        let projection = max(
            .zero,
            min(1, -(startPoint.x * deltaX + startPoint.y * deltaY) / squaredLength)
        )
        return hypot(startPoint.x + projection * deltaX, startPoint.y + projection * deltaY)
    }

    private static func localPoint(
        _ coordinate: GeographicCoordinate,
        origin: GeographicCoordinate,
        referenceLatitude: Double
    ) -> (x: Double, y: Double) {
        let longitudeDelta = (coordinate.longitudeDegrees - origin.longitudeDegrees) * .pi / 180
        let latitudeDelta = (coordinate.latitudeDegrees - origin.latitudeDegrees) * .pi / 180
        return (
            longitudeDelta * cos(referenceLatitude) * Constants.earthRadiusMeters,
            latitudeDelta * Constants.earthRadiusMeters
        )
    }

    private enum Constants {
        static let earthRadiusMeters = 6_371_000.0
    }
}
