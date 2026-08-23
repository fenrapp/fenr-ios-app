import BikeDomain

public struct BikeConnectionSessionPolicy: Sendable {
    public init() {}

    public func shouldResetSession(for state: ConnectionState) -> Bool {
        switch state {
        case .idle,
             .bluetoothUnavailable,
             .bluetoothUnauthorized,
             .bluetoothPoweredOff,
             .scanning,
             .reconnecting,
             .disconnected,
             .failed:
            true
        case .connecting,
             .discovering,
             .authenticating,
             .authenticated,
             .subscribed,
             .receivingTelemetry:
            false
        }
    }
}
