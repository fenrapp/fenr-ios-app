import Foundation

private final class BikeOnboardingResourceBundleToken {}

extension Bundle {
    static let bikeOnboarding = Bundle(for: BikeOnboardingResourceBundleToken.self)
}
