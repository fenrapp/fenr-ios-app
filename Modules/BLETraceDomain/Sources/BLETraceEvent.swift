import Foundation

public enum BLETraceDirection: String, Codable, Sendable {
    case inbound
    case outbound
    case internalEvent = "internal"
}

public enum BLETraceOperation: String, Codable, Sendable {
    case sessionStarted = "session_started"
    case centralStateChanged = "central_state_changed"
    case scanStarted = "scan_started"
    case scanStopped = "scan_stopped"
    case advertisementReceived = "advertisement_received"
    case connectedPeripheralRetrieved = "connected_peripheral_retrieved"
    case connectRequested = "connect_requested"
    case connectCompleted = "connect_completed"
    case connectFailed = "connect_failed"
    case disconnectRequested = "disconnect_requested"
    case disconnected
    case restoration
    case discoverServicesRequested = "discover_services_requested"
    case servicesDiscovered = "services_discovered"
    case discoverCharacteristicsRequested = "discover_characteristics_requested"
    case characteristicsDiscovered = "characteristics_discovered"
    case discoverDescriptorsRequested = "discover_descriptors_requested"
    case descriptorsDiscovered = "descriptors_discovered"
    case notificationStateRequested = "notification_state_requested"
    case notificationStateUpdated = "notification_state_updated"
    case readRequested = "read_requested"
    case valueUpdated = "value_updated"
    case writeRequested = "write_requested"
    case writeCompleted = "write_completed"
    case rssiRequested = "rssi_requested"
    case rssiReceived = "rssi_received"
    case decodeResult = "decode_result"
    case error
    case captureTruncated = "capture_truncated"
}

public enum BLETraceDecodeStatus: String, Codable, Sendable {
    case decoded
    case unmapped
    case failed
}

public struct BLETraceError: Codable, Equatable, Sendable {
    public let domain: String
    public let code: Int
    public let detail: String

    public init(domain: String, code: Int, detail: String) {
        self.domain = domain
        self.code = code
        self.detail = detail
    }
}

public struct BLETraceEvent: Codable, Equatable, Sendable {
    public let timestamp: Date
    public let uptimeNanoseconds: UInt64
    public let category: String
    public let operation: BLETraceOperation
    public let direction: BLETraceDirection
    public let serviceUUID: String?
    public let characteristicUUID: String?
    public let characteristicProperties: String?
    public let byteCount: Int?
    public let payloadHex: String?
    public let payloadRedacted: Bool
    public let decodeStatus: BLETraceDecodeStatus?
    public let readPending: Bool?
    public let detail: String?
    public let error: BLETraceError?

    public init(
        timestamp: Date,
        uptimeNanoseconds: UInt64,
        category: String,
        operation: BLETraceOperation,
        direction: BLETraceDirection,
        serviceUUID: String? = nil,
        characteristicUUID: String? = nil,
        characteristicProperties: String? = nil,
        byteCount: Int? = nil,
        payloadHex: String? = nil,
        payloadRedacted: Bool = false,
        decodeStatus: BLETraceDecodeStatus? = nil,
        readPending: Bool? = nil,
        detail: String? = nil,
        error: BLETraceError? = nil
    ) {
        self.timestamp = timestamp
        self.uptimeNanoseconds = uptimeNanoseconds
        self.category = category
        self.operation = operation
        self.direction = direction
        self.serviceUUID = serviceUUID
        self.characteristicUUID = characteristicUUID
        self.characteristicProperties = characteristicProperties
        self.byteCount = byteCount
        self.payloadHex = payloadHex
        self.payloadRedacted = payloadRedacted
        self.decodeStatus = decodeStatus
        self.readPending = readPending
        self.detail = detail
        self.error = error
    }
}
