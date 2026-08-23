public enum BikeSDKConnectionStatus: Equatable, Sendable {
    case idle
    case bluetoothUnavailable
    case bluetoothUnauthorized
    case bluetoothPoweredOff
    case scanning(vin: String)
    case connecting(vin: String, peripheralName: String?)
    case discovering(peripheralName: String?)
    case authenticating(peripheralName: String?)
    case authenticated(peripheralName: String?)
    case subscribed(peripheralName: String?)
    case receivingTelemetry(peripheralName: String?)
    case reconnecting(vin: String, attempt: Int, maximumAttempts: Int)
    case disconnected(reason: String?)
    case failed(message: String)
}
