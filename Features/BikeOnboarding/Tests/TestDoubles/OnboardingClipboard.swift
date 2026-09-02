@testable import BikeOnboarding

@MainActor
final class OnboardingClipboard: BikeOnboardingClipboardWriting {
    private(set) var copiedStrings: [String] = []

    func copy(_ text: String) {
        copiedStrings.append(text)
    }
}
