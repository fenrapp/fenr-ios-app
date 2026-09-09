public enum BikeSDKTractionControlError: Error, Equatable, Sendable {
    case connectionRecoveryRequired
    case unavailable
    case rejected
    case changed(BikeSDKTractionControlSnapshot)
    case mismatch(BikeSDKTractionControlSnapshot)
    case confirmationUnavailable
}
