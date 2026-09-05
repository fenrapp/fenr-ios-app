@preconcurrency import CoreLocation
import Foundation

final class TestHeading: CLHeading {
    override var magneticHeading: CLLocationDirection { 90 }
    override var trueHeading: CLLocationDirection { -1 }
    override var headingAccuracy: CLLocationDirection { 4 }
    override var timestamp: Date { Date(timeIntervalSince1970: 100) }
}
