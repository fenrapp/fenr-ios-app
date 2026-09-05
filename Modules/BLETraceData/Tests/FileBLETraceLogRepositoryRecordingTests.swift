import BLETraceData
import BLETraceDomain
import Foundation
import Testing

@Suite("BLE trace recording")
struct FileBLETraceLogRepositoryRecordingTests {
    @Test("Releasing the file writer disables its shared diagnostic gate")
    func releasingWriterDisablesCapture() async throws {
        var context: BLETraceDataTestContext? = makeBLETraceDataTestContext()
        let state = try #require(context?.captureState)
        let directory = try #require(context?.directory)
        defer { try? FileManager.default.removeItem(at: directory.deletingLastPathComponent()) }

        #expect(await context?.repository.startSession(BLETraceDataFixtures.session()) == true)
        #expect(state.isRecording)
        context = nil
        #expect(!state.isRecording)
    }

    @Test("Construction and ignored events do not touch the filesystem")
    func remainsLazyUntilExplicitCapture() async throws {
        let context = makeBLETraceDataTestContext()
        let state = context.captureState
        defer { try? FileManager.default.removeItem(at: context.directory.deletingLastPathComponent()) }
        #expect(!state.isRecording)
        await context.repository.record(BLETraceDataFixtures.event(index: 1))
        #expect(!FileManager.default.fileExists(atPath: context.directory.path))
        #expect(!FileManager.default.fileExists(atPath: context.exportDirectory.path))

        #expect(await context.repository.startSession(BLETraceDataFixtures.session()))
        #expect(state.isRecording)
        await context.repository.finishSession(reason: .userStopped)
        #expect(!state.isRecording)
        await context.repository.record(BLETraceDataFixtures.event(index: 2))
        let export = try await context.repository.prepareExport(sessionID: BLETraceDataFixtures.session().id)
        #expect(try !traceRecords(at: export).contains { $0["record_type"] as? String == "event" })
    }

    @Test("Writes ordered NDJSON and exports active and completed sessions")
    func writesAndExportsSessions() async throws {
        let context = makeBLETraceDataTestContext()
        defer { try? FileManager.default.removeItem(at: context.directory.deletingLastPathComponent()) }
        let session = BLETraceDataFixtures.session()

        await context.repository.startSession(session)
        await context.repository.record(BLETraceDataFixtures.event(index: 1))
        await context.repository.record(BLETraceDataFixtures.event(index: 2))

        let activeExport = try await context.repository.prepareExport(sessionID: session.id)
        let activeRecords = try traceRecords(at: activeExport)
        let activeExportBytes = try Data(contentsOf: activeExport).count
        #expect(activeRecords.first?["record_type"] as? String == "header")
        #expect(activeRecords.filter { $0["record_type"] as? String == "event" }.count == 2)
        #expect(activeRecords.last?["record_type"] as? String == "footer")
        #expect(activeRecords.last?["status"] as? String == "active")
        #expect(activeRecords.last?["reason"] as? String == "export_snapshot")
        #expect(activeRecords.last?["bytes"] as? Int == activeExportBytes)

        await context.repository.record(BLETraceDataFixtures.event(index: 3))
        #expect(try traceRecords(at: activeExport).count == activeRecords.count)

        await context.repository.finishSession(reason: .userDisconnected)
        let completedExport = try await context.repository.prepareExport(sessionID: session.id)
        let records = try traceRecords(at: completedExport)
        let completedExportBytes = try Data(contentsOf: completedExport).count
        #expect(records.last?["record_type"] as? String == "footer")
        #expect(records.last?["status"] as? String == "complete")
        #expect(records.last?["bytes"] as? Int == completedExportBytes)
        #expect(records.compactMap { $0["sequence"] as? Int } == [1, 2, 3])
    }

    @Test("Marks a session truncated when the storage limit is reached")
    func truncatesAtStorageLimit() async throws {
        let context = makeBLETraceDataTestContext(maximumTotalBytes: 1_200)
        defer { try? FileManager.default.removeItem(at: context.directory.deletingLastPathComponent()) }
        let session = BLETraceDataFixtures.session()

        await context.repository.startSession(session)
        await context.repository.record(
            BLETraceDataFixtures.event(index: 1, detail: String(repeating: "x", count: 2_000))
        )

        let stream = await context.repository.observeSessions()
        let sessions = await stream.first(where: { !$0.isEmpty }) ?? []
        #expect(sessions.first?.status == .truncated)
        let export = try await context.repository.prepareExport(sessionID: session.id)
        #expect(try traceRecords(at: export).last?["status"] as? String == "truncated")
    }

    @Test("Protects the active session from deletion")
    func protectsActiveSession() async throws {
        let context = makeBLETraceDataTestContext()
        defer { try? FileManager.default.removeItem(at: context.directory.deletingLastPathComponent()) }
        let session = BLETraceDataFixtures.session()
        await context.repository.startSession(session)

        await #expect(throws: BLETraceRepositoryError.activeSessionCannotBeDeleted) {
            try await context.repository.deleteSession(id: session.id)
        }
    }

    @Test("A canceled finish drains a blocked writer and closes a complete session")
    func canceledFinishDrainsBlockedWriter() async throws {
        let starter = ControllableBLETraceWriterTaskStarter()
        let context = makeBLETraceDataTestContext(writerTaskStarter: starter)
        defer { try? FileManager.default.removeItem(at: context.directory.deletingLastPathComponent()) }
        let session = BLETraceDataFixtures.session()
        await context.repository.startSession(session)
        await context.repository.record(BLETraceDataFixtures.event(index: 1))
        await starter.waitUntilStarted()

        let callerGate = BLETraceTestGate()
        let finishTask = Task {
            await callerGate.wait()
            await context.repository.finishSession(reason: .userDisconnected)
        }
        await callerGate.waitUntilBlocked()
        finishTask.cancel()
        await callerGate.open()
        await finishTask.value
        await starter.resumeAll()

        let export = try await context.repository.prepareExport(sessionID: session.id)
        let records = try traceRecords(at: export)
        #expect(records.map { $0["record_type"] as? String } == ["header", "event", "footer"])
        #expect(records.last?["status"] as? String == "complete")
    }

    @Test("Starting B drains and closes A before recording B")
    func startsSessionsInOrder() async throws {
        let starter = ControllableBLETraceWriterTaskStarter()
        let context = makeBLETraceDataTestContext(writerTaskStarter: starter)
        defer { try? FileManager.default.removeItem(at: context.directory.deletingLastPathComponent()) }
        let first = BLETraceDataFixtures.session(id: BLETraceDataFixtures.firstSessionID)
        let second = BLETraceDataFixtures.session(
            id: BLETraceDataFixtures.secondSessionID,
            startedAt: Date(timeIntervalSince1970: 20)
        )

        await context.repository.startSession(first)
        await context.repository.record(BLETraceDataFixtures.event(index: 1, detail: "A"))
        await starter.waitUntilStarted(count: 1)
        await context.repository.startSession(second)
        await context.repository.record(BLETraceDataFixtures.event(index: 2, detail: "B"))
        await starter.waitUntilStarted(count: 2)
        await context.repository.finishSession(reason: .userDisconnected)
        await starter.resumeAll()

        let firstExport = try await context.repository.prepareExport(sessionID: first.id)
        let secondExport = try await context.repository.prepareExport(sessionID: second.id)
        let firstRecords = try traceRecords(at: firstExport)
        let secondRecords = try traceRecords(at: secondExport)
        #expect(firstRecords.last?["reason"] as? String == "client_stopped")
        #expect(firstRecords.compactMap { $0["detail"] as? String } == ["A"])
        #expect(secondRecords.last?["reason"] as? String == "user_disconnected")
        #expect(secondRecords.compactMap { $0["detail"] as? String } == ["B"])
    }

    @Test("Multiple observers receive the same replay and session updates")
    func broadcastsSessionsToMultipleObservers() async throws {
        let context = makeBLETraceDataTestContext()
        defer { try? FileManager.default.removeItem(at: context.directory.deletingLastPathComponent()) }
        let firstStream = await context.repository.observeSessions()
        let secondStream = await context.repository.observeSessions()
        var firstIterator = firstStream.makeAsyncIterator()
        var secondIterator = secondStream.makeAsyncIterator()

        let firstReplay = await firstIterator.next()
        let secondReplay = await secondIterator.next()
        #expect(firstReplay?.isEmpty == true)
        #expect(secondReplay?.isEmpty == true)

        let session = BLETraceDataFixtures.session()
        await context.repository.startSession(session)
        let firstUpdate = await firstIterator.next()
        let secondUpdate = await secondIterator.next()
        #expect(firstUpdate?.map(\.id) == [session.id])
        #expect(secondUpdate?.map(\.id) == [session.id])
    }
}
