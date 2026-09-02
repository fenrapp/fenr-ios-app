import BikeOnboarding
import CoreBluetooth

@MainActor
struct SystemBikeOnboardingBluetoothAuthorizationProvider {
    var authorization: BikeOnboardingBluetoothAuthorization {
        switch CBManager.authorization {
        case .allowedAlways:
            .allowed
        case .denied, .restricted:
            .denied
        case .notDetermined:
            .notDetermined
        @unknown default:
            .notDetermined
        }
    }
}
