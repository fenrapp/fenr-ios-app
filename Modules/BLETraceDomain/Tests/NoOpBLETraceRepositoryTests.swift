import BLETraceDomain
import Foundation
import Testing

@Suite("No-op BLE trace repository")
struct NoOpBLETraceRepositoryTests {
    private let repository = NoOpBLETraceRepository()

    @Test("Completes the recording, preparation, and deletion cycle")
    func completesNoOpCycle() async throws {
        let sessionID = UUID()
        await repository.prepareStorage()
        await repository.startSession(.init(
            id: sessionID,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            startUptimeNanoseconds: 42,
            reason: .connectionRequest
        ))
        await repository.record(.init(
            timestamp: Date(timeIntervalSince1970: 1_700_000_001),
            uptimeNanoseconds: 43,
            category: "connection",
            operation: .connectCompleted,
            direction: .inbound
        ))
        await repository.finishSession(reason: .userDisconnected)
        try await repository.deleteSession(id: sessionID)
        try await repository.deleteAllSessions()
    }

    @Test("Observes one empty snapshot and then finishes")
    func observesEmptyFinishedStream() async {
        let stream = await repository.observeSessions()
        var iterator = stream.makeAsyncIterator()

        let firstSnapshot = await iterator.next()
        #expect(firstSnapshot?.isEmpty == true)
        #expect(await iterator.next() == nil)
    }

    @Test("Reports a missing session for every export")
    func reportsMissingExportSession() async {
        await #expect(throws: BLETraceRepositoryError.sessionNotFound) {
            try await repository.prepareExport(sessionID: UUID())
        }
    }
}
