import BikeOnboarding
import UIKit

@MainActor
struct SystemBikeOnboardingClipboard: BikeOnboardingClipboardWriting {
    func copy(_ text: String) {
        UIPasteboard.general.string = text
    }
}
