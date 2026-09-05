import BLETraceDomain
import Foundation

actor FakeBLETraceLogRepository: BLETraceLogRepository {
    private var continuation: AsyncStream<[BLETraceSessionSummary]>.Continuation?
    private var latestSessions: [BLETraceSessionSummary] = []
    private var failureContinuation: AsyncStream<BLETraceRecordingFailure?>.Continuation?
    private var latestFailure: BLETraceRecordingFailure?
    private(set) var exportedSessionIDs: [UUID] = []
    private(set) var deletedSessionIDs: [UUID] = []
    private(set) var deleteAllCount = 0
    var exportURL = URL(fileURLWithPath: "/tmp/fenr-test.jsonl")

    func prepareStorage() {}

    func observeRecordingFailures() -> AsyncStream<BLETraceRecordingFailure?> {
        let (stream, continuation) = AsyncStream<BLETraceRecordingFailure?>.makeStream()
        failureContinuation = continuation
        continuation.yield(latestFailure)
        return stream
    }

    func sendFailure(_ failure: BLETraceRecordingFailure?) {
        latestFailure = failure
        failureContinuation?.yield(failure)
    }

    func observeSessions() -> AsyncStream<[BLETraceSessionSummary]> {
        let (stream, continuation) = AsyncStream<[BLETraceSessionSummary]>.makeStream()
        self.continuation = continuation
        continuation.yield(latestSessions)
        return stream
    }

    func prepareExport(sessionID: UUID) -> URL {
        exportedSessionIDs.append(sessionID)
        return exportURL
    }

    func deleteSession(id: UUID) {
        deletedSessionIDs.append(id)
    }

    func deleteAllSessions() {
        deleteAllCount += 1
    }

    func send(_ sessions: [BLETraceSessionSummary]) {
        latestSessions = sessions
        continuation?.yield(sessions)
    }
}
