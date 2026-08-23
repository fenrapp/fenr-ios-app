import BikeDomain

public struct ConnectionStateToDisplayMapper: Sendable {
    public init() {}

    public func title(for state: ConnectionState) -> String {
        switch state {
        case .idle:
            "Idle"
        case .bluetoothUnavailable:
            "Bluetooth unavailable"
        case .bluetoothUnauthorized:
            "Bluetooth unauthorized"
        case .bluetoothPoweredOff:
            "Bluetooth off"
        case .scanning:
            "Scanning"
        case .connecting:
            "Connecting"
        case .discovering:
            "Discovering"
        case .authenticating:
            "Authenticating"
        case .authenticated:
            "Authenticated"
        case .subscribed:
            "Waiting for data"
        case .receivingTelemetry:
            "Receiving telemetry"
        case .reconnecting:
            "Reconnecting"
        case .disconnected:
            "Disconnected"
        case .failed:
            "Failed"
        }
    }

    public func detail(for state: ConnectionState) -> String {
        switch state {
        case .idle:
            "Ready"
        case .bluetoothUnavailable:
            "This device cannot use BLE central mode"
        case .bluetoothUnauthorized:
            "Bluetooth permission is required"
        case .bluetoothPoweredOff:
            "Enable Bluetooth"
        case .scanning(let vin):
            "Looking for \(vin)"
        case .connecting(let vin, let peripheralName):
            "Connecting to \(peripheralName ?? vin)"
        case .discovering(let peripheralName):
            "Discovering \(peripheralName ?? "bike")"
        case .authenticating(let peripheralName):
            "Completing Stark security with \(peripheralName ?? "bike")"
        case .authenticated(let peripheralName):
            "Security accepted; enabling SOC \(peripheralName ?? "")"
        case .subscribed(let peripheralName):
            "SOC notifications enabled \(peripheralName ?? "")"
        case .receivingTelemetry(let peripheralName):
            "Secure telemetry active \(peripheralName ?? "")"
        case .reconnecting(let vin, let attempt, let maximumAttempts):
            "Retrying \(vin) (\(attempt)/\(maximumAttempts))"
        case .disconnected(let reason):
            reason ?? "No active connection"
        case .failed(let message):
            message
        }
    }

    public func isActive(_ state: ConnectionState) -> Bool {
        switch state {
        case .scanning,
             .connecting,
             .discovering,
             .authenticating,
             .authenticated,
             .subscribed,
             .receivingTelemetry,
             .reconnecting:
            true
        default:
            false
        }
    }
}
