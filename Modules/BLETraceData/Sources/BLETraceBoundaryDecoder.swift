import BLETraceDomain
import Foundation

struct BLETraceBoundaryDecoder: Sendable {
    func decodeHeader(_ data: Data) -> BLETraceRecordCodec.HeaderBoundary? {
        guard let header = try? JSONDecoder().decode(StoredHeader.self, from: data),
              header.recordType == Constants.headerRecordType,
              header.schemaVersion == Constants.schemaVersion,
              let startedAt = parseTimestamp(header.startedAt) else { return nil }
        return .init(sessionID: header.sessionID, startedAt: startedAt)
    }

    func decodeSession(
        headerData: Data,
        footerData: Data
    ) -> BLETraceRecordCodec.SessionBoundary? {
        guard let header = decodeHeader(headerData),
              let footer = try? JSONDecoder().decode(StoredFooter.self, from: footerData),
              footer.recordType == Constants.footerRecordType,
              footer.schemaVersion == Constants.schemaVersion,
              footer.sessionID == header.sessionID,
              let endedAt = parseTimestamp(footer.endedAt),
              endedAt >= header.startedAt,
              footer.eventCount >= 0,
              let status = BLETraceSessionStatus(rawValue: footer.status) else { return nil }
        return .init(
            sessionID: header.sessionID,
            startedAt: header.startedAt,
            endedAt: endedAt,
            eventCount: footer.eventCount,
            status: status
        )
    }

    private func parseTimestamp(_ value: String) -> Date? {
        try? Date(value, strategy: .iso8601)
    }

    private struct StoredHeader: Decodable {
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

    private struct StoredFooter: Decodable {
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

    private enum Constants {
        static let schemaVersion = 1
        static let headerRecordType = "header"
        static let footerRecordType = "footer"
    }
}
