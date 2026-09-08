import EnvironmentDomain
import Foundation
import RideNavigationDomain

enum LongRecordingFixture {
    static let start = Date(timeIntervalSince1970: 1_700_000_000)

    static func point(_ index: Int, latitudeOffset: Double = 0) -> RideRoutePoint {
        RideRoutePoint(
            coordinate: GeographicCoordinate(
                latitudeDegrees: 40 + latitudeOffset + Double(index) * 0.00001, longitudeDegrees: -3
            )!,
            timestamp: start.addingTimeInterval(Double(index) * 5),
            horizontalAccuracyMeters: 5
        )
    }
}
