import BLETraceDomain
import Foundation

public struct ObserveBLETraceSessionsUseCase: Sendable {
    private let repository: any BLETraceLogRepository

    public init(repository: any BLETraceLogRepository) {
        self.repository = repository
    }

    public func execute() async -> AsyncStream<[BLETraceSessionSummary]> {
        await repository.observeSessions()
    }
}

public struct PrepareBLETraceExportUseCase: Sendable {
    private let repository: any BLETraceLogRepository

    public init(repository: any BLETraceLogRepository) {
        self.repository = repository
    }

    public func execute(sessionID: UUID) async throws -> URL {
        try await repository.prepareExport(sessionID: sessionID)
    }
}

public struct DeleteBLETraceSessionUseCase: Sendable {
    private let repository: any BLETraceLogRepository

    public init(repository: any BLETraceLogRepository) {
        self.repository = repository
    }

    public func execute(sessionID: UUID) async throws {
        try await repository.deleteSession(id: sessionID)
    }
}

public struct DeleteAllBLETraceSessionsUseCase: Sendable {
    private let repository: any BLETraceLogRepository

    public init(repository: any BLETraceLogRepository) {
        self.repository = repository
    }

    public func execute() async throws {
        try await repository.deleteAllSessions()
    }
}
