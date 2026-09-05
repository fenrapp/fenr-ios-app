@testable import BLETraceData
import BLETraceDomain
import Foundation
import Testing
import TestSupport

@Suite("BLE trace runtime storage failures")
struct FileBLETraceLogRepositoryFailureTests {
    @Test("Failure observation never prepares storage")
    func failureObservationIsLazy() async throws {
        let context = makeBLETraceDataTestContext()
        let stream = await context.repository.observeRecordingFailures()
        var iterator = stream.makeAsyncIterator()
        let replay = await iterator.next()
        #expect(replay != nil)
        #expect(replay.flatMap { $0 } == nil)
        #expect(!FileManager.default.fileExists(atPath: context.directory.path))
    }

    @Test("History preparation exposes a sessionless failure and clears it on retry")
    func historyFailureIsObservableAndRetryable() async throws {
        let controller = FileOperationFailureController()
        let context = makeBLETraceDataTestContext(fileManager: ControlledFileManager(controller: controller))
        defer { try? FileManager.default.removeItem(at: context.directory.deletingLastPathComponent()) }
        controller.failNextContents(of: context.directory)
        let stream = await context.repository.observeSessions()
        var sessions = stream.makeAsyncIterator()
        #expect(await sessions.next()?.isEmpty == true)
        #expect(await waitUntil { await context.repository.recordingFailure?.phase == .preparing })
        let failures = await context.repository.observeRecordingFailures()
        var iterator = failures.makeAsyncIterator()
        let replay = await iterator.next()
        #expect(replay.flatMap { $0 } == .init(sessionID: nil, phase: .preparing))

        await context.repository.prepareStorage()
        let cleared = await iterator.next()
        #expect(cleared != nil)
        #expect(cleared.flatMap { $0 } == nil)
        #expect(await context.repository.hasPreparedStorage)
    }

    @Test("Body write failure stops admission, replays the error and preserves the partial")
    func bodyFailureIsObservableAndRecoverable() async throws {
        let context = makeBLETraceDataTestContext()
        defer { try? FileManager.default.removeItem(at: context.directory.deletingLastPathComponent()) }
        let session = BLETraceDataFixtures.session()
        #expect(await context.repository.startSession(session))
        try await context.repository.closeActiveFileHandleForTesting()
        await context.repository.record(BLETraceDataFixtures.event(index: 1))
        #expect(await waitUntil { await context.repository.recordingFailure?.phase == .writing })
        #expect(!context.captureState.isRecording)
        #expect(await context.repository.currentSummaries().first?.status == .incomplete)
        #expect(await context.repository.finishSession(reason: .userStopped) == false)

        let failures = await context.repository.observeRecordingFailures()
        var iterator = failures.makeAsyncIterator()
        let replay = await iterator.next()
        #expect(replay.flatMap { $0 } == .init(sessionID: session.id, phase: .writing))
        let exported = try await context.repository.prepareExport(sessionID: session.id)
        #expect(try traceRecords(at: exported).last?["status"] as? String == "incomplete")
        #expect(await context.repository.recordingFailure?.phase == .writing)
    }

    @Test("Footer failure returns false and clears only after a successful new Start")
    func footerFailureDoesNotReportSuccess() async throws {
        let context = makeBLETraceDataTestContext()
        defer { try? FileManager.default.removeItem(at: context.directory.deletingLastPathComponent()) }
        let session = BLETraceDataFixtures.session()
        #expect(await context.repository.startSession(session))
        await context.repository.record(BLETraceDataFixtures.event(index: 1))
        _ = try await context.repository.prepareExport(sessionID: session.id)
        try await context.repository.closeActiveFileHandleForTesting()

        #expect(await context.repository.finishSession(reason: .userStopped) == false)
        #expect(!context.captureState.isRecording)
        #expect(await context.repository.currentSummaries().first?.status == .incomplete)
        let failures = await context.repository.observeRecordingFailures()
        var iterator = failures.makeAsyncIterator()
        let replay = await iterator.next()
        #expect(replay.flatMap { $0 } == .init(sessionID: session.id, phase: .finishing))
        let export = try await context.repository.prepareExport(sessionID: session.id)
        let records = try traceRecords(at: export)
        #expect(records.compactMap { $0["sequence"] as? Int } == [1])
        #expect(records.last?["status"] as? String == "incomplete")

        let next = BLETraceDataFixtures.session(id: BLETraceDataFixtures.secondSessionID)
        #expect(await context.repository.startSession(next))
        let cleared = await iterator.next()
        #expect(cleared != nil)
        #expect(cleared.flatMap { $0 } == nil)
        #expect(await context.repository.finishSession(reason: .userStopped))
    }
}
