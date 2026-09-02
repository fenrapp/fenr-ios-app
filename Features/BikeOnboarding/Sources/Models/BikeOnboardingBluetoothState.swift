public enum BikeOnboardingBluetoothState: Equatable, Sendable {
    case preparation
    case requestingAccess
    case denied
    case poweredOff
    case unavailable
}
