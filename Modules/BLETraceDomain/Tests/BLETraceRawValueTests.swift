import BLETraceDomain
import Testing

@Suite("BLE trace persisted raw values")
struct BLETraceRawValueTests {
    @Test("Direction raw values remain persistence-stable", arguments: [
        (BLETraceDirection.inbound, "inbound"),
        (.outbound, "outbound"),
        (.internalEvent, "internal")
    ])
    func directionRawValues(direction: BLETraceDirection, expected: String) {
        #expect(direction.rawValue == expected)
    }

    @Test("Operation raw values remain persistence-stable", arguments: [
        (BLETraceOperation.sessionStarted, "session_started"),
        (.centralStateChanged, "central_state_changed"),
        (.scanStarted, "scan_started"),
        (.scanStopped, "scan_stopped"),
        (.advertisementReceived, "advertisement_received"),
        (.connectedPeripheralRetrieved, "connected_peripheral_retrieved"),
        (.connectRequested, "connect_requested"),
        (.connectCompleted, "connect_completed"),
        (.connectFailed, "connect_failed"),
        (.connectionStateChanged, "connection_state_changed"),
        (.disconnectRequested, "disconnect_requested"),
        (.disconnected, "disconnected"),
        (.restoration, "restoration"),
        (.discoverServicesRequested, "discover_services_requested"),
        (.servicesDiscovered, "services_discovered"),
        (.discoverCharacteristicsRequested, "discover_characteristics_requested"),
        (.characteristicsDiscovered, "characteristics_discovered"),
        (.discoverDescriptorsRequested, "discover_descriptors_requested"),
        (.descriptorsDiscovered, "descriptors_discovered"),
        (.notificationStateRequested, "notification_state_requested"),
        (.notificationStateUpdated, "notification_state_updated"),
        (.readRequested, "read_requested"),
        (.valueUpdated, "value_updated"),
        (.writeRequested, "write_requested"),
        (.writeCompleted, "write_completed"),
        (.rssiRequested, "rssi_requested"),
        (.rssiReceived, "rssi_received"),
        (.decodeResult, "decode_result"),
        (.error, "error"),
        (.captureTruncated, "capture_truncated")
    ])
    func operationRawValues(operation: BLETraceOperation, expected: String) {
        #expect(operation.rawValue == expected)
    }

    @Test("Decode status raw values remain persistence-stable", arguments: [
        (BLETraceDecodeStatus.decoded, "decoded"),
        (.unmapped, "unmapped"),
        (.failed, "failed")
    ])
    func decodeStatusRawValues(status: BLETraceDecodeStatus, expected: String) {
        #expect(status.rawValue == expected)
    }

    @Test("Session start raw values remain persistence-stable", arguments: [
        (BLETraceSessionStartReason.connectionRequest, "connection_request"),
        (.restoration, "restoration")
    ])
    func sessionStartRawValues(reason: BLETraceSessionStartReason, expected: String) {
        #expect(reason.rawValue == expected)
    }

    @Test("Session end raw values remain persistence-stable", arguments: [
        (BLETraceSessionEndReason.userDisconnected, "user_disconnected"),
        (.clientStopped, "client_stopped"),
        (.reconnectExhausted, "reconnect_exhausted"),
        (.pairingResetRequired, "pairing_reset_required"),
        (.abruptTermination, "abrupt_termination"),
        (.storageLimitReached, "storage_limit_reached"),
        (.exportSnapshot, "export_snapshot")
    ])
    func sessionEndRawValues(reason: BLETraceSessionEndReason, expected: String) {
        #expect(reason.rawValue == expected)
    }

    @Test("Session status raw values remain persistence-stable", arguments: [
        (BLETraceSessionStatus.active, "active"),
        (.complete, "complete"),
        (.incomplete, "incomplete"),
        (.truncated, "truncated")
    ])
    func sessionStatusRawValues(status: BLETraceSessionStatus, expected: String) {
        #expect(status.rawValue == expected)
    }
}
