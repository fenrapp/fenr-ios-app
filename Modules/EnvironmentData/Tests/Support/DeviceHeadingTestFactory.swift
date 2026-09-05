import CoreLocation
import EnvironmentData

@MainActor
func makeDeviceHeadingRepository(
    manager: TestLocationManager, available: Bool = true
) -> CoreLocationDeviceHeadingRepository {
    .init(locationManager: manager, isHeadingAvailable: { available }, headingOrientation: { .landscapeLeft })
}
