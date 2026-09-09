public enum BikeTractionControlError: Error, Equatable, Sendable {
    case connectionRecoveryRequired
    case unavailable
    case rejected
    case changed(BikeTractionControlSnapshot)
    case mismatch(BikeTractionControlSnapshot)
    case confirmationUnavailable
}
