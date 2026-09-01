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

}
