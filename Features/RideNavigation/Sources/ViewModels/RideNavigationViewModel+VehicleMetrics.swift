import BikeDomain
import VehicleSession

@MainActor
extension RideNavigationViewModel {
    func updateVehicleMetricCache(from snapshot: VehicleSessionSnapshot) {
        if snapshot.isCanonicalTelemetryAvailable {
            if let percentage = snapshot.telemetry.batteryLevel.percent {
                lastValidBatteryText = "\(percentage)%"
            }
            if snapshot.telemetry.mode.displayIndex != nil {
                lastValidModeText = resolvedModeText
            }
            return
        }
        guard isTerminalConnection(snapshot.connection.state) else { return }
        lastValidBatteryText = nil
        lastValidModeText = nil
    }

    private func isTerminalConnection(_ connection: ConnectionState) -> Bool {
        switch connection {
        case .idle, .bluetoothUnavailable, .bluetoothUnauthorized, .bluetoothPoweredOff,
             .pairingResetRequired, .disconnected, .failed:
            true
        case .scanning, .connecting, .discovering, .authenticating, .authenticated,
             .subscribed, .receivingTelemetry, .reconnecting:
            false
        }
    }
}
