import Foundation

enum BikeOnboardingL10n {
    static func text(_ resource: LocalizedStringResource) -> String { String(localized: resource) }

    static func stepAccessibility(index: Int, count: Int, title: String, detail: String) -> String {
        text(.bikeOnboardingAccessibilityStep(index, count, title, detail))
    }

    static func progressAccessibility(title: String, step: Int, count: Int) -> String {
        text(.bikeOnboardingAccessibilityConnectionProgressValue(title, step, count))
    }

    static func bikeAccessibility(title: String, vin: String, signal: String, rssi: String) -> String {
        text(.bikeOnboardingAccessibilityBike(title, vin, signal, rssi))
    }
}
