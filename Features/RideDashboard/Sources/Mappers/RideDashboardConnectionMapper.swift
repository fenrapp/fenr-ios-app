import BikeDomain

public struct RideDashboardConnectionMapper: Sendable {
    public init() {}

    func text(_ state: ConnectionState) -> String {
        switch state {
        case .idle: "Restoring bike session"
        case .reconnecting(_, let attempt, let maximumAttempts): "Reconnecting (\(attempt)/\(maximumAttempts))"
        case .pairingResetRequired(let message): message
        case .scanning: "Scanning for bike"
        case .connecting: "Connecting"
        case .discovering: "Discovering bike services"
        case .authenticating: "Authenticating"
        case .authenticated: "Enabling live telemetry"
        case .subscribed: "Waiting for live telemetry"
        case .receivingTelemetry: "Live telemetry active"
        case .disconnected(let reason): reason ?? "Disconnected"
        case .failed(let message): message
        case .bluetoothUnavailable: "Bluetooth is unavailable"
        case .bluetoothPoweredOff: "Bluetooth is off"
        case .bluetoothUnauthorized: "Bluetooth access is required"
        }
    }

    func showsProgress(_ state: ConnectionState) -> Bool {
        switch state {
        case .idle, .scanning, .connecting, .discovering, .authenticating,
             .authenticated, .subscribed, .receivingTelemetry, .reconnecting:
            true
        case .bluetoothUnavailable, .bluetoothUnauthorized, .bluetoothPoweredOff,
             .pairingResetRequired, .disconnected, .failed:
            false
        }
    }

    func hasTelemetry(_ telemetry: BikeTelemetry, connection: BikeConnection) -> Bool {
        guard case .receivingTelemetry = connection.state else { return false }
        return telemetry.speed.kmh != nil
            || telemetry.batteryLevel.percent != nil
            || telemetry.odometer.kilometers != nil
    }

    func displaySpeed(_ speed: Double, runState: BikeRunState) -> Double {
        speed < .zero && runState != .crawlReverse ? .zero : speed
    }
}
