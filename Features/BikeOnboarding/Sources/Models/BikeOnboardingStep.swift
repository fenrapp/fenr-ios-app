public enum BikeOnboardingStep: Int, CaseIterable, Hashable, Sendable {
    case welcome
    case bluetooth
    case discovery
    case pairing
    case connecting
    case success
}
