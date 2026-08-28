import BLETraceDomain
import Foundation

extension FileBLETraceLogRepository {
    struct ActiveSession {
        let context: BLETraceSessionContext
        let url: URL
        let fileHandle: FileHandle
        var nextSequence: Int
        var eventCount: Int
        var bytesWritten: Int64
        var isTruncated: Bool
    }

    struct StoredSession {
        let summary: BLETraceSessionSummary
        let url: URL
    }

    struct PendingLine {
        let sessionID: UUID
        let data: Data
    }

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

    struct FooterInput {
        let sessionID: UUID
        let endedAt: Date
        let durationMilliseconds: Int64
        let eventCount: Int
        let baseBytes: Int64
        let status: BLETraceSessionStatus
        let reason: BLETraceSessionEndReason
    }

    static func encodeFooter(
        _ input: FooterInput,
        lineEncoder: BLETraceJSONLineEncoder
    ) throws -> Data {
        var totalBytes = input.baseBytes
        for _ in 0 ..< 4 {
            let data = try lineEncoder.encode(makeFooter(input, bytes: totalBytes))
            let resolvedBytes = input.baseBytes + Int64(data.count)
            guard resolvedBytes != totalBytes else { return data }
            totalBytes = resolvedBytes
        }
        return try lineEncoder.encode(makeFooter(input, bytes: totalBytes))
    }

    private static func makeFooter(_ input: FooterInput, bytes: Int64) -> FooterRecord {
        FooterRecord(
            recordType: "footer",
            schemaVersion: 1,
            sessionID: input.sessionID,
            endedAt: timestamp(input.endedAt),
            durationMilliseconds: input.durationMilliseconds,
            eventCount: input.eventCount,
            bytes: bytes,
            status: input.status.rawValue,
            reason: input.reason.rawValue
        )
    }
}
