import BikeDomain

public struct BikeConnectionToConnectionPanelMapper: Sendable {
    private let stateMapper: ConnectionStateToDisplayMapper

    public init(stateMapper: ConnectionStateToDisplayMapper) {
        self.stateMapper = stateMapper
    }

    public func map(_ connection: BikeConnection) -> ConnectionPanelViewData {
        ConnectionPanelViewData(
            status: stateMapper.title(for: connection.state),
            detail: stateMapper.detail(for: connection.state),
            rssi: connection.rssi.map { "\($0) dBm" } ?? BikeDiagnosticsText.emptyRSSI,
            peripheral: peripheralText(connection),
            emphasis: stateMapper.emphasis(for: connection.state)
        )
    }

    public func isDisconnectEnabled(_ connection: BikeConnection) -> Bool {
        stateMapper.isActive(connection.state)
    }

    public func isVINEditingEnabled(_ connection: BikeConnection) -> Bool {
        switch connection.state {
        case .receivingTelemetry, .reconnecting:
            return false
        default:
            return true
        }
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

    private func peripheralText(_ connection: BikeConnection) -> String {
        let values = [connection.peripheralName, connection.peripheralIdentifier?.uuidString].compactMap { $0 }
        let text = values.joined(separator: "\n")
        return text.isEmpty ? BikeDiagnosticsText.noPeripheral : text
    }
}
