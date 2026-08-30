import BLETraceDomain
import Foundation

enum BLETraceDataFixtures {
    static let firstSessionID = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
    static let secondSessionID = UUID(uuidString: "00000000-0000-0000-0000-000000000102")!

    static func session(
        id: UUID = firstSessionID,
        startedAt: Date = Date(timeIntervalSince1970: 10)
    ) -> BLETraceSessionContext {
        BLETraceSessionContext(
            id: id,
            startedAt: startedAt,
            startUptimeNanoseconds: 10_000_000_000,
            reason: .connectionRequest
        )
    }

    static func event(
        index: Int,
        detail: String? = nil,
        payloadHex: String? = "AA BB",
        payloadRedacted: Bool = false,
        serviceUUID: String? = nil,
        characteristicUUID: String? = "00006004-5374-6172-4B20-467574757265"
    ) -> BLETraceEvent {
        BLETraceEvent(
            timestamp: Date(timeIntervalSince1970: 10 + Double(index)),
            uptimeNanoseconds: 10_000_000_000 + UInt64(index) * 1_000_000,
            category: "gatt",
            operation: .valueUpdated,
            direction: .inbound,
            serviceUUID: serviceUUID,
            characteristicUUID: characteristicUUID,
            byteCount: 2,
            payloadHex: payloadHex,
            payloadRedacted: payloadRedacted,
            detail: detail
        )
    }

    static func header(
        id: UUID,
        recordType: String = "header",
        schemaVersion: Int = 1,
        startedAt: String = "1970-01-01T00:00:10.000Z"
    ) -> [String: Any] {
        [
            "record_type": recordType,
            "schema_version": schemaVersion,
            "session_id": id.uuidString,
            "started_at": startedAt
        ]
    }

    static func eventRecord(id: UUID, sequence: Int = 1) -> [String: Any] {
        [
            "record_type": "event",
            "schema_version": 1,
            "session_id": id.uuidString,
            "sequence": sequence
        ]
    }

    static func footer(
        id: UUID,
        recordType: String = "footer",
        schemaVersion: Int = 1,
        endedAt: String = "1970-01-01T00:01:10.000Z",
        eventCount: Int = 1,
        status: String = "complete"
    ) -> [String: Any] {
        [
            "record_type": recordType,
            "schema_version": schemaVersion,
            "session_id": id.uuidString,
            "ended_at": endedAt,
            "event_count": eventCount,
            "status": status
        ]
    }
}
