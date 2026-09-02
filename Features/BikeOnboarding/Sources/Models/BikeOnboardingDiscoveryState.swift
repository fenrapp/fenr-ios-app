public enum BikeOnboardingDiscoveryState: Equatable, Sendable {
    case scanning
    case stabilizing
    case multiple
    case timedOut
    case paused
    case failed
}
