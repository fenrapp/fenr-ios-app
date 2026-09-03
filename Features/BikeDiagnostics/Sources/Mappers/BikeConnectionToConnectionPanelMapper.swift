import BikeDomain

public struct BikeConnectionToConnectionPanelMapper: Sendable {
    private let stateMapper: ConnectionStateToDisplayMapper

    public init(stateMapper: ConnectionStateToDisplayMapper) {
        self.stateMapper = stateMapper
    }

    public func map(_ connection: BikeConnection, configuredVIN: String?) -> ConnectionPanelViewData {
        ConnectionPanelViewData(
            status: stateMapper.title(for: connection.state),
            detail: stateMapper.detail(for: connection.state),
            rssi: connection.rssi.map { "\($0) dBm" } ?? BikeDiagnosticsText.emptyRSSI,
            configuredVIN: configuredVIN ?? BikeDiagnosticsText.placeholder,
            peripheralName: connection.peripheralName ?? BikeDiagnosticsText.noPeripheral,
            peripheralIdentifier: connection.peripheralIdentifier?.uuidString
                ?? BikeDiagnosticsText.placeholder,
            emphasis: stateMapper.emphasis(for: connection.state)
        )
    }

    public func isDisconnectEnabled(_ connection: BikeConnection) -> Bool {
        stateMapper.isActive(connection.state)
    }

    public func isPairRetryEnabled(_ connection: BikeConnection) -> Bool {
        switch connection.state {
        case .discovering, .authenticating, .authenticated, .subscribed, .receivingTelemetry:
            true
        case .idle,
             .bluetoothUnavailable,
             .bluetoothUnauthorized,
             .bluetoothPoweredOff,
             .scanning,
             .connecting,
             .reconnecting,
             .pairingResetRequired,
             .disconnected,
             .failed:
            false
        }
    }

    public func isReadSnapshotEnabled(_ connection: BikeConnection) -> Bool {
        switch connection.state {
        case .authenticated, .subscribed, .receivingTelemetry:
            true
        default:
            false
        }
    }

    public func isBatteryHealthEnabled(_ connection: BikeConnection) -> Bool {
        if case .receivingTelemetry = connection.state {
            return true
        }
        return false
    }

    public func isReconnectEnabled(_ connection: BikeConnection, configuredVIN: String?) -> Bool {
        guard configuredVIN?.isEmpty == false else { return false }
        switch connection.state {
        case .scanning, .connecting, .discovering, .authenticating, .authenticated,
             .subscribed, .receivingTelemetry, .reconnecting:
            return false
        default:
            return true
        }
    }
}
