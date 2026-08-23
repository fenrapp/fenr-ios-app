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
        case .scanning(let vin):
            "Scanning for \(vin)"
        case .connecting(let vin, let peripheralName):
            "Connecting to \(peripheralName ?? vin)"
        case .discovering(let peripheralName):
            "Discovering \(peripheralName ?? "bike")"
        case .authenticating(let peripheralName):
            "Authenticating \(peripheralName ?? "bike")"
        case .authenticated(let peripheralName):
            "Authenticated \(peripheralName ?? "bike")"
        case .subscribed(let peripheralName):
            "Subscribed \(peripheralName ?? "bike")"
        case .receivingTelemetry(let peripheralName):
            "Receiving telemetry from \(peripheralName ?? "bike")"
        case .reconnecting(let vin, let attempt, let maximumAttempts):
            "Reconnecting to \(vin) (\(attempt)/\(maximumAttempts))"
        case .disconnected(let reason):
            "Disconnected \(reason ?? "")"
        case .failed(let message):
            "Failed \(message)"
        }
    }
}
