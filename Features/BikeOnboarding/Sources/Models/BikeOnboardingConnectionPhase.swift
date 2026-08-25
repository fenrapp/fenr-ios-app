public enum BikeOnboardingConnectionPhase: Int, CaseIterable, Sendable {
    case scanning
    case connecting
    case discovering
    case authenticating
    case subscribing
}
