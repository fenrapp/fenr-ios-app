@testable import BikeOnboarding

@MainActor
final class OnboardingBluetoothAuthorizationProvider {
    var authorization: BikeOnboardingBluetoothAuthorization

    init(_ authorization: BikeOnboardingBluetoothAuthorization) {
        self.authorization = authorization
    }
}
