import BLETraceDomain
import Foundation

struct BLETraceRecordCodec: Sendable {
    struct FooterInput: Sendable {
        let sessionID: UUID
        let endedAt: Date
        let durationMilliseconds: Int64
        let eventCount: Int
        let baseBytes: Int64
        let status: BLETraceSessionStatus
        let reason: BLETraceSessionEndReason
    }

    struct HeaderBoundary: Equatable, Sendable {
        let sessionID: UUID
        let startedAt: Date
    }

    struct SessionBoundary: Equatable, Sendable {
        let sessionID: UUID
        let startedAt: Date
        let endedAt: Date
        let eventCount: Int
        let status: BLETraceSessionStatus
    }

    private let lineEncoder: BLETraceJSONLineEncoder

    init(lineEncoder: BLETraceJSONLineEncoder) {
        self.lineEncoder = lineEncoder
    }

    func encodeHeader(
        context: BLETraceSessionContext,
        environment: BLETraceEnvironment
    ) throws -> Data {
        try lineEncoder.encode(HeaderRecord(
            recordType: Constants.headerRecordType,
            schemaVersion: Constants.schemaVersion,
            sessionID: context.id,
            startedAt: Self.timestamp(context.startedAt),
            startReason: context.reason.rawValue,
            appVersion: environment.appVersion,
            appBuild: environment.appBuild,
            operatingSystem: environment.operatingSystem,
            deviceModel: environment.deviceModel,
            privacyPolicy: Constants.privacyPolicy
        ))
    }

    func encodeEvent(
        _ event: BLETraceEvent,
        sessionID: UUID,
        sequence: Int,
        startUptimeNanoseconds: UInt64
    ) throws -> Data {
        try lineEncoder.encode(EventRecord(
            recordType: Constants.eventRecordType,
            schemaVersion: Constants.schemaVersion,
            sessionID: sessionID,
            sequence: sequence,
            timestamp: Self.timestamp(event.timestamp),
            elapsedMilliseconds: Self.elapsedMilliseconds(
                event.uptimeNanoseconds,
                since: startUptimeNanoseconds
            ),
            category: event.category,
            operation: event.operation.rawValue,
            direction: event.direction.rawValue,
            serviceUUID: event.serviceUUID,
            characteristicUUID: event.characteristicUUID,
            characteristicProperties: event.characteristicProperties,
            byteCount: event.byteCount,
            payloadHex: event.payloadRedacted ? nil : event.payloadHex,
            payloadRedacted: event.payloadRedacted,
            decodeStatus: event.decodeStatus?.rawValue,
            readPending: event.readPending,
            detail: event.detail,
            error: event.error
        ))
    }

    func encodeStorageLimitMarker(
        sessionID: UUID,
        sequence: Int,
        timestamp: Date,
        uptimeNanoseconds: UInt64,
        startUptimeNanoseconds: UInt64
    ) throws -> Data {
        try lineEncoder.encode(EventRecord(
            recordType: Constants.eventRecordType,
            schemaVersion: Constants.schemaVersion,
            sessionID: sessionID,
            sequence: sequence,
            timestamp: Self.timestamp(timestamp),
            elapsedMilliseconds: Self.elapsedMilliseconds(
                uptimeNanoseconds,
                since: startUptimeNanoseconds
            ),
            category: Constants.storageCategory,
            operation: BLETraceOperation.captureTruncated.rawValue,
            direction: BLETraceDirection.internalEvent.rawValue,
            serviceUUID: nil,
            characteristicUUID: nil,
            characteristicProperties: nil,
            byteCount: nil,
            payloadHex: nil,
            payloadRedacted: false,
            decodeStatus: nil,
            readPending: nil,
            detail: Constants.storageLimitDetail,
            error: nil
        ))
    }

    func encodeFooter(_ input: FooterInput) throws -> Data {
        var totalBytes = input.baseBytes
        for _ in 0 ..< Constants.footerResolutionAttempts {
            let data = try lineEncoder.encode(makeFooter(input, bytes: totalBytes))
            let resolvedBytes = input.baseBytes + Int64(data.count)
            guard resolvedBytes != totalBytes else { return data }
            totalBytes = resolvedBytes
        }
        return try lineEncoder.encode(makeFooter(input, bytes: totalBytes))
    }

    func decodeHeaderBoundary(_ data: Data) -> HeaderBoundary? {
        guard let header = try? JSONDecoder().decode(StoredHeaderBoundary.self, from: data),
              header.recordType == Constants.headerRecordType,
              header.schemaVersion == Constants.schemaVersion,
              let startedAt = Self.parseTimestamp(header.startedAt) else { return nil }
        return HeaderBoundary(sessionID: header.sessionID, startedAt: startedAt)
    }

    func decodeSessionBoundary(
        headerData: Data,
        footerData: Data
    ) -> SessionBoundary? {
        guard let header = decodeHeaderBoundary(headerData),
              let footer = try? JSONDecoder().decode(StoredFooterBoundary.self, from: footerData),
              footer.recordType == Constants.footerRecordType,
              footer.schemaVersion == Constants.schemaVersion,
              footer.sessionID == header.sessionID,
              let endedAt = Self.parseTimestamp(footer.endedAt),
              endedAt >= header.startedAt,
              footer.eventCount >= 0,
              let status = BLETraceSessionStatus(rawValue: footer.status) else { return nil }
        return SessionBoundary(
            sessionID: header.sessionID,
            startedAt: header.startedAt,
            endedAt: endedAt,
            eventCount: footer.eventCount,
            status: status
        )
    }
}

private extension BLETraceRecordCodec {
    struct HeaderRecord: Codable {
        let recordType: String
        let schemaVersion: Int
        let sessionID: UUID
        let startedAt: String
        let startReason: String
        let appVersion: String
        let appBuild: String
        let operatingSystem: String
        let deviceModel: String
        let privacyPolicy: String

        enum CodingKeys: String, CodingKey {
            case recordType = "record_type"
            case schemaVersion = "schema_version"
            case sessionID = "session_id"
            case startedAt = "started_at"
            case startReason = "start_reason"
            case appVersion = "app_version"
            case appBuild = "app_build"
            case operatingSystem = "operating_system"
            case deviceModel = "device_model"
            case privacyPolicy = "privacy_policy"
        }
    }

    struct EventRecord: Codable {
        let recordType: String
        let schemaVersion: Int
        let sessionID: UUID
        let sequence: Int
        let timestamp: String
        let elapsedMilliseconds: Int64
        let category: String
        let operation: String
        let direction: String
        let serviceUUID: String?
        let characteristicUUID: String?
        let characteristicProperties: String?
        let byteCount: Int?
        let payloadHex: String?
        let payloadRedacted: Bool
        let decodeStatus: String?
        let readPending: Bool?
        let detail: String?
        let error: BLETraceError?

        enum CodingKeys: String, CodingKey {
            case recordType = "record_type"
            case schemaVersion = "schema_version"
            case sessionID = "session_id"
            case sequence, timestamp, category, operation, direction, detail, error
            case elapsedMilliseconds = "elapsed_ms"
            case serviceUUID = "service_uuid"
            case characteristicUUID = "characteristic_uuid"
            case characteristicProperties = "characteristic_properties"
            case byteCount = "byte_count"
            case payloadHex = "payload_hex"
            case payloadRedacted = "payload_redacted"
            case decodeStatus = "decode_status"
            case readPending = "read_pending"
        }
    }

    struct FooterRecord: Codable {
        let recordType: String
        let schemaVersion: Int
        let sessionID: UUID
        let endedAt: String
        let durationMilliseconds: Int64
        let eventCount: Int
        let bytes: Int64
        let status: String
        let reason: String

        enum CodingKeys: String, CodingKey {
            case recordType = "record_type"
            case schemaVersion = "schema_version"
            case sessionID = "session_id"
            case endedAt = "ended_at"
            case durationMilliseconds = "duration_ms"
            case eventCount = "event_count"
            case bytes, status, reason
        }
    }

    struct StoredHeaderBoundary: Decodable {
        let recordType: String
        let schemaVersion: Int
        let sessionID: UUID
        let startedAt: String

        enum CodingKeys: String, CodingKey {
            case recordType = "record_type"
            case schemaVersion = "schema_version"
            case sessionID = "session_id"
            case startedAt = "started_at"
        }
    }

    struct StoredFooterBoundary: Decodable {
        let recordType: String
        let schemaVersion: Int
        let sessionID: UUID
        let endedAt: String
        let eventCount: Int
        let status: String

        enum CodingKeys: String, CodingKey {
            case recordType = "record_type"
            case schemaVersion = "schema_version"
            case sessionID = "session_id"
            case endedAt = "ended_at"
            case eventCount = "event_count"
            case status
        }
    }

    func makeFooter(_ input: FooterInput, bytes: Int64) -> FooterRecord {
        FooterRecord(
            recordType: Constants.footerRecordType,
            schemaVersion: Constants.schemaVersion,
            sessionID: input.sessionID,
            endedAt: Self.timestamp(input.endedAt),
            durationMilliseconds: input.durationMilliseconds,
            eventCount: input.eventCount,
            bytes: bytes,
            status: input.status.rawValue,
            reason: input.reason.rawValue
        )
    }

    static func timestamp(_ date: Date) -> String {
        Date.ISO8601FormatStyle(includingFractionalSeconds: true, timeZone: .gmt).format(date)
    }

    static func elapsedMilliseconds(_ uptime: UInt64, since start: UInt64) -> Int64 {
        guard uptime >= start else { return 0 }
        return Int64((uptime - start) / 1_000_000)
    }

    static func parseTimestamp(_ value: String) -> Date? {
        try? Date(value, strategy: .iso8601)
    }

    enum Constants {
        static let schemaVersion = 1
        static let headerRecordType = "header"
        static let eventRecordType = "event"
        static let footerRecordType = "footer"
        static let privacyPolicy = "vin_peripheral_and_authentication_redacted"
        static let storageCategory = "storage"
        static let storageLimitDetail = "Trace stopped after reaching the configured storage limit"
        static let footerResolutionAttempts = 4
    }
}
