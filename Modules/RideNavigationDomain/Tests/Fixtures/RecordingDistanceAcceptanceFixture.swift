import EnvironmentDomain
import Foundation
import RideNavigationDomain

enum RecordingDistanceAcceptanceFixture {
    static let start = Date(timeIntervalSince1970: 1_700_000_000)

    static func point(latitude: Double, seconds: TimeInterval, accuracy: Double = 5) -> RideRoutePoint {
        RideRoutePoint(
            coordinate: GeographicCoordinate(latitudeDegrees: latitude, longitudeDegrees: 2)!,
            timestamp: start.addingTimeInterval(seconds),
            horizontalAccuracyMeters: accuracy
        )
    }
}
