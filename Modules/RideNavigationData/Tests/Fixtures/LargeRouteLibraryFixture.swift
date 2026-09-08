import EnvironmentDomain
import Foundation
import RideNavigationDomain

enum LargeRouteLibraryFixture {
    static func points(count: Int) -> [RideRoutePoint] {
        (0 ..< count).map { index in
            RideRoutePoint(
                coordinate: GeographicCoordinate(latitudeDegrees: 40 + Double(index) * 0.00001, longitudeDegrees: -3)!,
                timestamp: Date(timeIntervalSince1970: Double(index) * 5),
                horizontalAccuracyMeters: 5
            )
        }
    }
}
