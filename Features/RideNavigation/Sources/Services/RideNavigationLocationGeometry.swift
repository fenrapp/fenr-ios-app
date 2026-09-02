import Foundation
import RideNavigationDomain

public struct RideNavigationLocationGeometry: Sendable {
    public init() {}

    func routePoint(from snapshot: RideNavigationLocationSnapshot) -> RideRoutePoint? {
        guard let coordinate = snapshot.coordinate,
              let observedAt = snapshot.observedAt else { return nil }
        return RideRoutePoint(
            coordinate: coordinate,
            elevationMeters: snapshot.altitudeMeters,
            timestamp: observedAt,
            horizontalAccuracyMeters: snapshot.horizontalAccuracyMeters
        )
    }

    func relativeBearingDegrees(_ bearingDegrees: Double, courseDegrees: Double?) -> Double {
        let fullCircleDegrees = 360.0
        let halfCircleDegrees = fullCircleDegrees / 2
        var delta = (bearingDegrees - (courseDegrees ?? .zero))
            .truncatingRemainder(dividingBy: fullCircleDegrees)
        if delta > halfCircleDegrees {
            delta -= fullCircleDegrees
        } else if delta < -halfCircleDegrees {
            delta += fullCircleDegrees
        }
        return delta
    }
}
