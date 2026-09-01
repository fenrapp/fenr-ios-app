import BikeDomain

public struct RideDashboardContinuityPolicy: Sendable {
    public init() {}

    public func phase(
        connectionState: ConnectionState,
        hasLiveTelemetry: Bool,
        hasValidPresentation: Bool
    ) -> RideDashboardContinuityPhase {
        if hasLiveTelemetry {
            return .live
        }
        switch connectionState {
        case .bluetoothUnavailable,
             .bluetoothUnauthorized,
             .bluetoothPoweredOff,
             .pairingResetRequired,
             .disconnected,
             .failed:
            return .terminal
        case .idle,
             .scanning,
             .connecting,
             .discovering,
             .authenticating,
             .authenticated,
             .subscribed,
             .receivingTelemetry,
             .reconnecting:
            return hasValidPresentation ? .recovering : .cold
        }
    }
}
