import Foundation

public protocol BLETraceRecording: Sendable {
    @discardableResult
    func startSession(_ context: BLETraceSessionContext) async -> Bool
    func record(_ event: BLETraceEvent) async
    @discardableResult
    func finishSession(reason: BLETraceSessionEndReason) async -> Bool
}

public protocol BLETraceStoragePreparing: Sendable {
    func prepareStorage() async
}

public protocol BLETraceLogRepository: BLETraceStoragePreparing, Sendable {
    func observeRecordingFailures() async -> AsyncStream<BLETraceRecordingFailure?>
    func observeSessions() async -> AsyncStream<[BLETraceSessionSummary]>
    func prepareExport(sessionID: UUID) async throws -> URL
    func deleteSession(id: UUID) async throws
    func deleteAllSessions() async throws
}

public enum BLETraceRepositoryError: Error, Equatable, Sendable {
    case sessionNotFound
    case activeSessionCannotBeDeleted
    case unableToCreateStorage
    case unableToExport
}

public struct NoOpBLETraceRepository: BLETraceRecording, BLETraceLogRepository, Sendable {
    public init() {}

    @discardableResult
    public func startSession(_ context: BLETraceSessionContext) async -> Bool { false }
    public func record(_ event: BLETraceEvent) async {}
    @discardableResult
    public func finishSession(reason: BLETraceSessionEndReason) async -> Bool { false }
    public func prepareStorage() async {}

    public func observeSessions() async -> AsyncStream<[BLETraceSessionSummary]> {
        AsyncStream { continuation in
            continuation.yield([])
            continuation.finish()
        }
    }

    public func prepareExport(sessionID: UUID) async throws -> URL {
        throw BLETraceRepositoryError.sessionNotFound
    }

    public func deleteSession(id: UUID) async throws {}
    public func deleteAllSessions() async throws {}
}

extension BLETraceLogRepository {
    public func observeRecordingFailures() async -> AsyncStream<BLETraceRecordingFailure?> {
        AsyncStream { continuation in
            continuation.yield(nil)
            continuation.finish()
        }
    }
}
