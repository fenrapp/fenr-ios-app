import BikeDomain

public struct RideDashboardConnectionMapper: Sendable {
    public init() {}

    func text(_ state: ConnectionState) -> String {
        switch state {
        case .idle: rideDashboardLocalized(.rideDashboardConnectionRestoring)
        case .reconnecting(_, let attempt, let maximumAttempts):
            rideDashboardLocalized(.rideDashboardConnectionReconnectingAttempt(attempt, maximumAttempts))
        case .pairingResetRequired:
            rideDashboardLocalized(.rideDashboardConnectionPairingResetRequired)
        case .scanning: rideDashboardLocalized(.rideDashboardConnectionScanning)
        case .connecting: rideDashboardLocalized(.rideDashboardConnectionConnecting)
        case .discovering: rideDashboardLocalized(.rideDashboardConnectionDiscovering)
        case .authenticating: rideDashboardLocalized(.rideDashboardConnectionAuthenticating)
        case .authenticated: rideDashboardLocalized(.rideDashboardConnectionEnablingTelemetry)
        case .subscribed: rideDashboardLocalized(.rideDashboardConnectionWaitingTelemetry)
        case .receivingTelemetry: rideDashboardLocalized(.rideDashboardConnectionLive)
        case .disconnected: rideDashboardLocalized(.rideDashboardConnectionDisconnected)
        case .failed: rideDashboardLocalized(.rideDashboardConnectionFailed)
        case .bluetoothUnavailable: rideDashboardLocalized(.rideDashboardConnectionBluetoothUnavailable)
        case .bluetoothPoweredOff: rideDashboardLocalized(.rideDashboardConnectionBluetoothOff)
        case .bluetoothUnauthorized: rideDashboardLocalized(.rideDashboardConnectionBluetoothRequired)
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
