import BLETraceData
import BLETraceDomain
import Foundation
import Testing

@Suite("BLE trace maintenance")
struct FileBLETraceLogRepositoryMaintenanceTests {
    @Test("Retains only the configured newest sessions")
    func prunesOldSessionsAndTheirExport() async throws {
        let context = makeBLETraceDataTestContext(maximumSessionCount: 2)
        defer { try? FileManager.default.removeItem(at: context.directory.deletingLastPathComponent()) }
        var firstExport: URL?

        for index in 0 ..< 3 {
            let id = UUID(uuidString: "00000000-0000-0000-0000-00000000020\(index)")!
            let session = BLETraceDataFixtures.session(
                id: id,
                startedAt: Date(timeIntervalSince1970: Double(index))
            )
            await context.repository.startSession(session)
            await context.repository.record(BLETraceDataFixtures.event(index: index))
            await context.repository.finishSession(reason: .userDisconnected)
            if index == 0 {
                firstExport = try await context.repository.prepareExport(sessionID: id)
            }
        }

        let sessions = await context.repository.observeSessions().first { !$0.isEmpty } ?? []
        #expect(sessions.map(\.startedAt) == [
            Date(timeIntervalSince1970: 2),
            Date(timeIntervalSince1970: 1)
        ])
        #expect(firstExport.map { !FileManager.default.fileExists(atPath: $0.path) } == true)
    }

    @Test("Prunes a sole trace that exceeds the total byte limit")
    func prunesSoleOversizedTrace() async throws {
        let root = temporaryBLETraceRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let logs = root.appendingPathComponent("logs", isDirectory: true)
        try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        let trace = logs.appendingPathComponent("oversized.jsonl")
        try writeCompletedTrace(
            to: trace,
            id: BLETraceDataFixtures.firstSessionID,
            paddingBytes: 4_096
        )

        let context = makeBLETraceDataTestContext(maximumTotalBytes: 1_024, root: root)
        let stream = await context.repository.observeSessions()
        var iterator = stream.makeAsyncIterator()
        let snapshot = await iterator.next()
        #expect(snapshot?.isEmpty == true)
        #expect(!FileManager.default.fileExists(atPath: trace.path))
    }

    @Test("Uses UUID ascending order when session start dates tie")
    func ordersTiesByUUID() async throws {
        let root = temporaryBLETraceRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let logs = root.appendingPathComponent("logs", isDirectory: true)
        try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        let first = BLETraceDataFixtures.firstSessionID
        let second = BLETraceDataFixtures.secondSessionID
        try writeCompletedTrace(to: logs.appendingPathComponent("second.jsonl"), id: second)
        try writeCompletedTrace(to: logs.appendingPathComponent("first.jsonl"), id: first)

        let context = makeBLETraceDataTestContext(root: root)
        let sessions = await context.repository.observeSessions().first { !$0.isEmpty } ?? []
        #expect(sessions.map(\.id) == [first, second])
    }

    @Test("A failed delete reconciles the on-disk session and removes its export")
    func reconcilesAfterDeleteFailure() async throws {
        let controller = FileOperationFailureController()
        let context = makeBLETraceDataTestContext(
            fileManager: ControlledFileManager(controller: controller)
        )
        defer { try? FileManager.default.removeItem(at: context.directory.deletingLastPathComponent()) }
        let session = BLETraceDataFixtures.session()
        await context.repository.startSession(session)
        await context.repository.finishSession(reason: .userDisconnected)
        let export = try await context.repository.prepareExport(sessionID: session.id)
        let log = context.directory.appendingPathComponent(export.lastPathComponent)
        controller.failNextRemoval(of: log)

        await #expect(throws: CocoaError.self) {
            try await context.repository.deleteSession(id: session.id)
        }
        let sessions = await context.repository.observeSessions().first { !$0.isEmpty } ?? []
        #expect(sessions.map(\.id) == [session.id])
        #expect(!FileManager.default.fileExists(atPath: export.path))
    }

    @Test("A partial bulk delete reconciles storage and cleans exact exports")
    func reconcilesAfterPartialBulkDelete() async throws {
        let controller = FileOperationFailureController()
        let context = makeBLETraceDataTestContext(
            fileManager: ControlledFileManager(controller: controller)
        )
        defer { try? FileManager.default.removeItem(at: context.directory.deletingLastPathComponent()) }
        let first = BLETraceDataFixtures.session(id: BLETraceDataFixtures.firstSessionID)
        let second = BLETraceDataFixtures.session(
            id: BLETraceDataFixtures.secondSessionID,
            startedAt: Date(timeIntervalSince1970: 20)
        )
        await context.repository.startSession(first)
        await context.repository.finishSession(reason: .userDisconnected)
        await context.repository.startSession(second)
        await context.repository.finishSession(reason: .userDisconnected)
        let firstExport = try await context.repository.prepareExport(sessionID: first.id)
        let secondExport = try await context.repository.prepareExport(sessionID: second.id)
        controller.failNextRemoval(
            of: context.directory.appendingPathComponent(firstExport.lastPathComponent)
        )

        await #expect(throws: CocoaError.self) {
            try await context.repository.deleteAllSessions()
        }
        let sessions = await context.repository.observeSessions().first { !$0.isEmpty } ?? []
        #expect(sessions.map(\.id) == [first.id])
        #expect(!FileManager.default.fileExists(atPath: firstExport.path))
        #expect(!FileManager.default.fileExists(atPath: secondExport.path))
    }

    @Test("Preparation removes every legacy export and reexport replaces the exact destination")
    func cleansLegacyExportsAndReexportsExactly() async throws {
        let root = temporaryBLETraceRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let exports = root.appendingPathComponent("exports", isDirectory: true)
        try FileManager.default.createDirectory(at: exports, withIntermediateDirectories: true)
        let legacy = exports.appendingPathComponent("legacy.txt")
        try Data("legacy".utf8).write(to: legacy)
        let context = makeBLETraceDataTestContext(root: root)
        let session = BLETraceDataFixtures.session()
        await context.repository.startSession(session)
        await context.repository.finishSession(reason: .userDisconnected)
        #expect(!FileManager.default.fileExists(atPath: legacy.path))

        let first = try await context.repository.prepareExport(sessionID: session.id)
        try Data("stale".utf8).write(to: first)
        let second = try await context.repository.prepareExport(sessionID: session.id)
        #expect(first == second)
        #expect(try traceRecords(at: second).last?["status"] as? String == "complete")
    }

    @Test("Canceled maintenance operations do not mutate storage")
    func canceledMaintenanceDoesNotMutate() async throws {
        let context = makeBLETraceDataTestContext()
        defer { try? FileManager.default.removeItem(at: context.directory.deletingLastPathComponent()) }
        let session = BLETraceDataFixtures.session()
        await context.repository.startSession(session)
        await context.repository.finishSession(reason: .userDisconnected)

        let exportGate = BLETraceTestGate()
        let exportTask = Task {
            await exportGate.wait()
            return try await context.repository.prepareExport(sessionID: session.id)
        }
        await exportGate.waitUntilBlocked()
        exportTask.cancel()
        await exportGate.open()
        await #expect(throws: CancellationError.self) { try await exportTask.value }

        let deleteGate = BLETraceTestGate()
        let deleteTask = Task {
            await deleteGate.wait()
            try await context.repository.deleteAllSessions()
        }
        await deleteGate.waitUntilBlocked()
        deleteTask.cancel()
        await deleteGate.open()
        await #expect(throws: CancellationError.self) { try await deleteTask.value }
        let sessions = await context.repository.observeSessions().first { !$0.isEmpty } ?? []
        #expect(sessions.map(\.id) == [session.id])
        #expect(try FileManager.default.contentsOfDirectory(
            at: context.exportDirectory,
            includingPropertiesForKeys: nil
        ).isEmpty)
    }

    @Test("An export failure removes the copied destination")
    func removesDestinationAfterExportFailure() async throws {
        let controller = FileOperationFailureController()
        let context = makeBLETraceDataTestContext(
            fileManager: ControlledFileManager(controller: controller)
        )
        defer { try? FileManager.default.removeItem(at: context.directory.deletingLastPathComponent()) }
        let session = BLETraceDataFixtures.session()
        await context.repository.startSession(session)
        await context.repository.finishSession(reason: .userDisconnected)
        let summary = await context.repository.observeSessions().first { !$0.isEmpty }?.first
        let fileName = try #require(summary?.fileName)
        let destination = context.exportDirectory.appendingPathComponent(fileName)
        controller.failNextAttributes(of: destination)

        await #expect(throws: BLETraceRepositoryError.unableToExport) {
            try await context.repository.prepareExport(sessionID: session.id)
        }
        #expect(!FileManager.default.fileExists(atPath: destination.path))
    }

    @Test("Storage failure is deferred until Start and reports failure")
    func reportsStorageInitializationFailure() async throws {
        let root = temporaryBLETraceRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try Data([0x01]).write(to: root)

        let context = makeBLETraceDataTestContext(root: root)
        #expect(await context.repository.startSession(BLETraceDataFixtures.session()) == false)
    }

    @Test("Directories, logs, and exports use protected storage")
    func configuresProtectedStorage() async throws {
        let context = makeBLETraceDataTestContext()
        defer { try? FileManager.default.removeItem(at: context.directory.deletingLastPathComponent()) }
        let session = BLETraceDataFixtures.session()
        await context.repository.startSession(session)
        await context.repository.finishSession(reason: .userDisconnected)
        let export = try await context.repository.prepareExport(sessionID: session.id)
        let log = context.directory.appendingPathComponent(export.lastPathComponent)

        try assertStorageProtection(at: context.directory)
        try assertStorageProtection(at: context.exportDirectory)
        try assertStorageProtection(at: log)
        try assertStorageProtection(at: export)
    }
}
