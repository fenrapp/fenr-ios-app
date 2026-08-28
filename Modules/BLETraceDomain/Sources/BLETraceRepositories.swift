import Foundation

public protocol BLETraceRecording: Sendable {
    func startSession(_ context: BLETraceSessionContext) async
    func record(_ event: BLETraceEvent) async
    func finishSession(reason: BLETraceSessionEndReason) async
}

public protocol BLETraceStoragePreparing: Sendable {
    func prepareStorage() async
}

public protocol BLETraceLogRepository: BLETraceStoragePreparing, Sendable {
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

public actor NoOpBLETraceRepository: BLETraceRecording, BLETraceLogRepository {
    public init() {}

    public func startSession(_ context: BLETraceSessionContext) {}
    public func record(_ event: BLETraceEvent) {}
    public func finishSession(reason: BLETraceSessionEndReason) {}
    public func prepareStorage() {}

    public func observeSessions() -> AsyncStream<[BLETraceSessionSummary]> {
        AsyncStream { continuation in
            continuation.yield([])
            continuation.finish()
        }
    }

    public func prepareExport(sessionID: UUID) throws -> URL {
        throw BLETraceRepositoryError.sessionNotFound
    }

    public func deleteSession(id: UUID) throws {}
    public func deleteAllSessions() throws {}
}
