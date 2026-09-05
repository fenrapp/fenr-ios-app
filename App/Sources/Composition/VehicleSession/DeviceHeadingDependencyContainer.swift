import CoreLocation
import EnvironmentData
import UIKit

@MainActor
enum DeviceHeadingDependencyContainer {
    static func makeRepository() -> CoreLocationDeviceHeadingRepository {
        CoreLocationDeviceHeadingRepository(
            locationManager: CLLocationManager(),
            isHeadingAvailable: CLLocationManager.headingAvailable,
            headingOrientation: {
                let orientation = UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .first { $0.activationState == .foregroundActive }?.interfaceOrientation
                switch orientation {
                case .landscapeLeft: return .landscapeRight
                case .landscapeRight: return .landscapeLeft
                case .portraitUpsideDown: return .portraitUpsideDown
                default: return .portrait
                }
            }
        )
    }
}
