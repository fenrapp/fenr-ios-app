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

public struct NoOpBLETraceRepository: BLETraceRecording, BLETraceLogRepository, Sendable {
    public init() {}

    public func startSession(_ context: BLETraceSessionContext) async {}
    public func record(_ event: BLETraceEvent) async {}
    public func finishSession(reason: BLETraceSessionEndReason) async {}
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
