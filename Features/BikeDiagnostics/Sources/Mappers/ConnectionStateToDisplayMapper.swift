import BikeDomain
import Foundation

public struct ConnectionStateToDisplayMapper: Sendable {
    public init() {}

    public func title(for state: ConnectionState) -> String {
        switch state {
        case .idle:
            BikeDiagnosticsL10n.text(.bikeDiagnosticsConnectionIdle)
        case .bluetoothUnavailable:
            BikeDiagnosticsL10n.text(.bikeDiagnosticsConnectionBluetoothUnavailable)
        case .bluetoothUnauthorized:
            BikeDiagnosticsL10n.text(.bikeDiagnosticsConnectionBluetoothUnauthorized)
        case .bluetoothPoweredOff:
            BikeDiagnosticsL10n.text(.bikeDiagnosticsConnectionBluetoothOff)
        case .scanning:
            BikeDiagnosticsL10n.text(.bikeDiagnosticsConnectionScanning)
        case .connecting:
            BikeDiagnosticsL10n.text(.bikeDiagnosticsConnectionConnecting)
        case .discovering:
            BikeDiagnosticsL10n.text(.bikeDiagnosticsConnectionDiscovering)
        case .authenticating:
            BikeDiagnosticsL10n.text(.bikeDiagnosticsConnectionAuthenticating)
        case .authenticated:
            BikeDiagnosticsL10n.text(.bikeDiagnosticsConnectionAuthenticated)
        case .subscribed:
            BikeDiagnosticsL10n.text(.bikeDiagnosticsConnectionWaiting)
        case .receivingTelemetry:
            BikeDiagnosticsL10n.text(.bikeDiagnosticsConnectionReceivingTelemetry)
        case .reconnecting:
            BikeDiagnosticsL10n.text(.bikeDiagnosticsConnectionReconnecting)
        case .pairingResetRequired:
            BikeDiagnosticsL10n.text(.bikeDiagnosticsConnectionPairingResetRequired)
        case .disconnected:
            BikeDiagnosticsL10n.text(.bikeDiagnosticsConnectionDisconnected)
        case .failed:
            BikeDiagnosticsL10n.text(.bikeDiagnosticsConnectionFailed)
        }
    }

    public func detail(for state: ConnectionState) -> String {
        switch state {
        case .idle:
            BikeDiagnosticsL10n.text(.bikeDiagnosticsConnectionDetailReady)
        case .bluetoothUnavailable:
            BikeDiagnosticsL10n.text(.bikeDiagnosticsConnectionDetailUnavailable)
        case .bluetoothUnauthorized:
            BikeDiagnosticsL10n.text(.bikeDiagnosticsConnectionDetailUnauthorized)
        case .bluetoothPoweredOff:
            BikeDiagnosticsL10n.text(.bikeDiagnosticsConnectionDetailBluetoothOff)
        case .scanning(let vin):
            BikeDiagnosticsL10n.text(.bikeDiagnosticsConnectionDetailScanning(vin))
        case .connecting(let vin, let peripheralName):
            BikeDiagnosticsL10n.text(.bikeDiagnosticsConnectionDetailConnecting(peripheralName ?? vin))
        case .discovering(let peripheralName):
            BikeDiagnosticsL10n.text(.bikeDiagnosticsConnectionDetailDiscovering(
                peripheralName ?? BikeDiagnosticsL10n.text(.bikeDiagnosticsBikeFallback)
            ))
        case .authenticating(let peripheralName):
            BikeDiagnosticsL10n.text(.bikeDiagnosticsConnectionDetailAuthenticating(
                peripheralName ?? BikeDiagnosticsL10n.text(.bikeDiagnosticsBikeFallback)
            ))
        case .authenticated(let peripheralName):
            BikeDiagnosticsL10n.text(.bikeDiagnosticsConnectionDetailAuthenticated(
                peripheralName ?? BikeDiagnosticsL10n.text(.bikeDiagnosticsBikeFallback)
            ))
        case .subscribed(let peripheralName):
            BikeDiagnosticsL10n.text(.bikeDiagnosticsConnectionDetailSubscribed(
                peripheralName ?? BikeDiagnosticsL10n.text(.bikeDiagnosticsBikeFallback)
            ))
        case .receivingTelemetry(let peripheralName):
            BikeDiagnosticsL10n.text(.bikeDiagnosticsConnectionDetailReceiving(
                peripheralName ?? BikeDiagnosticsL10n.text(.bikeDiagnosticsBikeFallback)
            ))
        case .reconnecting(let vin, let attempt, let maximumAttempts):
            BikeDiagnosticsL10n.text(.bikeDiagnosticsConnectionDetailReconnecting(vin, attempt, maximumAttempts))
        case .pairingResetRequired:
            BikeDiagnosticsL10n.text(.bikeDiagnosticsConnectionDetailPairingReset)
        case .disconnected:
            BikeDiagnosticsL10n.text(.bikeDiagnosticsConnectionDetailDisconnected)
        case .failed:
            BikeDiagnosticsL10n.text(.bikeDiagnosticsConnectionDetailFailed)
        }
    }

    public func emphasis(for state: ConnectionState) -> ConnectionPanelViewData.Emphasis {
        switch state {
        case .receivingTelemetry:
            .success
        case .scanning, .connecting, .discovering, .authenticating, .authenticated, .subscribed, .reconnecting:
            .progress
        case .bluetoothPoweredOff, .pairingResetRequired, .disconnected:
            .warning
        case .bluetoothUnavailable, .bluetoothUnauthorized, .failed:
            .critical
        case .idle:
            .neutral
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
