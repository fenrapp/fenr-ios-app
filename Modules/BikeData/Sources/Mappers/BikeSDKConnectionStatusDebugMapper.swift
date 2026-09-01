import BikeSDK

public struct BikeSDKConnectionStatusDebugMapper: Sendable {
    public init() {}

    public func map(_ status: BikeSDKConnectionStatus) -> String {
        switch status {
        case .idle:
            "Idle"
        case .bluetoothUnavailable:
            "Bluetooth unavailable"
        case .bluetoothUnauthorized:
            "Bluetooth unauthorized"
        case .bluetoothPoweredOff:
            "Bluetooth powered off"
        case .scanning:
            "Scanning for bike"
        case .connecting:
            "Connecting to bike"
        case .discovering:
            "Discovering bike"
        case .authenticating:
            "Authenticating bike"
        case .authenticated:
            "Authenticated bike"
        case .subscribed:
            "Subscribed to bike"
        case .receivingTelemetry:
            "Receiving telemetry"
        case .reconnecting(_, let attempt, let maximumAttempts):
            "Reconnecting (\(attempt)/\(maximumAttempts))"
        case .pairingResetRequired:
            "Pairing reset required"
        case .disconnected:
            "Disconnected"
        case .failed:
            "Connection failed"
        }
    }
}
