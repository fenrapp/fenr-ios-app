import BLETraceData
import BLETraceDomain
import Foundation
import Testing

@Suite("BLE trace recovery and schema")
struct FileBLETraceLogRepositoryRecoveryTests {
    @Test("Recovers partial files as protected incomplete sessions")
    func recoversPartialFiles() async throws {
        let root = temporaryBLETraceRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let logs = root.appendingPathComponent("logs", isDirectory: true)
        try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        let id = BLETraceDataFixtures.firstSessionID
        let partial = logs.appendingPathComponent("interrupted.partial")
        try partialTrace(id: id).write(to: partial)

        let context = makeBLETraceDataTestContext(root: root)
        let sessions = await context.repository.observeSessions().first { !$0.isEmpty } ?? []

        #expect(sessions.first?.id == id)
        #expect(sessions.first?.status == .incomplete)
        let export = try await context.repository.prepareExport(sessionID: id)
        #expect(try traceRecords(at: export).last?["reason"] as? String == "abrupt_termination")
        let recovered = partial.deletingPathExtension().appendingPathExtension("jsonl")
        try assertStorageProtection(at: recovered)
    }

    @Test("Initialization stays lazy and repeated preparation is idempotent")
    func preparesHistoryLazilyOnce() async throws {
        let root = temporaryBLETraceRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let logs = root.appendingPathComponent("logs", isDirectory: true)
        try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        let id = BLETraceDataFixtures.firstSessionID
        let partial = logs.appendingPathComponent("lazy.partial")
        try partialTrace(id: id).write(to: partial)

        let context = makeBLETraceDataTestContext(root: root)
        #expect(FileManager.default.fileExists(atPath: partial.path))

        await context.repository.prepareStorage()
        await context.repository.prepareStorage()
        let sessions = await context.repository.observeSessions().first { !$0.isEmpty } ?? []
        #expect(sessions.map(\.id) == [id])
        #expect(sessions.first?.status == .incomplete)
    }

    @Test("Loads a sparse large trace using bounded boundary reads")
    func loadsLargeSparseTraceFromBoundaries() async throws {
        let root = temporaryBLETraceRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let logs = root.appendingPathComponent("logs", isDirectory: true)
        try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        let id = BLETraceDataFixtures.firstSessionID
        let trace = logs.appendingPathComponent("large.jsonl")
        #expect(FileManager.default.createFile(atPath: trace.path, contents: nil))
        let handle = try FileHandle(forWritingTo: trace)
        try handle.write(contentsOf: jsonLine(BLETraceDataFixtures.header(id: id)))
        try handle.seek(toOffset: 256 * 1_024 * 1_024)
        try handle.write(contentsOf: Data([0x0A]))
        try handle.write(contentsOf: jsonLine(BLETraceDataFixtures.footer(id: id, eventCount: 123)))
        try handle.close()

        let context = makeBLETraceDataTestContext(
            maximumTotalBytes: 512 * 1_024 * 1_024,
            root: root
        )
        let sessions = await context.repository.observeSessions().first { !$0.isEmpty } ?? []

        #expect(sessions.count == 1)
        #expect(sessions.first?.id == id)
        #expect(sessions.first?.eventCount == 123)
        #expect((sessions.first?.fileSizeBytes ?? 0) > 250 * 1_024 * 1_024)
    }

    @Test("Preserves every corrupt or unknown schema file without exposing it")
    func preservesInvalidSchemaPermutations() async throws {
        let root = temporaryBLETraceRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let logs = root.appendingPathComponent("logs", isDirectory: true)
        try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        let cases = invalidBoundaries()

        for (index, boundary) in cases.enumerated() {
            let url = logs.appendingPathComponent("invalid-\(index).jsonl")
            try completedTrace(header: boundary.header, footer: boundary.footer).write(to: url)
        }

        let context = makeBLETraceDataTestContext(root: root)
        let stream = await context.repository.observeSessions()
        var iterator = stream.makeAsyncIterator()
        let firstSnapshot = await iterator.next()
        #expect(firstSnapshot?.isEmpty == true)
        for index in cases.indices {
            #expect(FileManager.default.fileExists(
                atPath: logs.appendingPathComponent("invalid-\(index).jsonl").path
            ))
        }
    }

    @Test("A failed recovery remains partial while other recovered files are protected")
    func leavesFailedRecoveryPartial() async throws {
        let root = temporaryBLETraceRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let logs = root.appendingPathComponent("logs", isDirectory: true)
        try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        let failedPartial = logs.appendingPathComponent("failed.partial")
        let validPartial = logs.appendingPathComponent("valid.partial")
        try partialTrace(id: BLETraceDataFixtures.firstSessionID).write(to: failedPartial)
        try partialTrace(id: BLETraceDataFixtures.secondSessionID).write(to: validPartial)
        let controller = FileOperationFailureController()
        let fileManager = ControlledFileManager(controller: controller)
        let context = makeBLETraceDataTestContext(root: root, fileManager: fileManager)
        controller.failNextMove(from: failedPartial)

        let sessions = await context.repository.observeSessions().first { !$0.isEmpty } ?? []

        #expect(Set(sessions.map(\.id)) == Set([
            BLETraceDataFixtures.firstSessionID, BLETraceDataFixtures.secondSessionID
        ]))
        #expect(sessions.first { $0.id == BLETraceDataFixtures.firstSessionID }?.status == .incomplete)
        #expect(FileManager.default.fileExists(atPath: failedPartial.path))
        let recovered = validPartial.deletingPathExtension().appendingPathExtension("jsonl")
        try assertStorageProtection(at: recovered)

        let retryContext = makeBLETraceDataTestContext(root: root)
        let retried = await retryContext.repository.observeSessions().first { $0.count == 2 } ?? []
        let failedSession = retried.first { $0.id == BLETraceDataFixtures.firstSessionID }
        #expect(failedSession?.status == .incomplete)
        #expect(failedSession?.eventCount == 1)
        #expect(!FileManager.default.fileExists(atPath: failedPartial.path))
    }

    @Test("A transient preparation failure can be retried")
    func retriesTransientPreparationFailure() async throws {
        let root = temporaryBLETraceRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let logs = root.appendingPathComponent("logs", isDirectory: true)
        try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        let partial = logs.appendingPathComponent("retry.partial")
        try partialTrace(id: BLETraceDataFixtures.firstSessionID).write(to: partial)
        let controller = FileOperationFailureController()
        let context = makeBLETraceDataTestContext(
            root: root,
            fileManager: ControlledFileManager(controller: controller)
        )
        controller.failNextContents(of: logs)

        await context.repository.prepareStorage()
        #expect(FileManager.default.fileExists(atPath: partial.path))
        await context.repository.prepareStorage()
        let sessions = await context.repository.observeSessions().first { !$0.isEmpty } ?? []
        #expect(sessions.map(\.id) == [BLETraceDataFixtures.firstSessionID])
    }

    private func invalidBoundaries() -> [InvalidBoundary] {
        let first = BLETraceDataFixtures.firstSessionID
        let second = BLETraceDataFixtures.secondSessionID
        return [
            InvalidBoundary(
                header: BLETraceDataFixtures.header(id: first, recordType: "unknown"),
                footer: BLETraceDataFixtures.footer(id: first)
            ),
            InvalidBoundary(
                header: BLETraceDataFixtures.header(id: first, schemaVersion: 2),
                footer: BLETraceDataFixtures.footer(id: first)
            ),
            InvalidBoundary(
                header: BLETraceDataFixtures.header(id: first),
                footer: BLETraceDataFixtures.footer(id: first, recordType: "unknown")
            ),
            InvalidBoundary(
                header: BLETraceDataFixtures.header(id: first),
                footer: BLETraceDataFixtures.footer(id: first, schemaVersion: 2)
            ),
            InvalidBoundary(
                header: BLETraceDataFixtures.header(id: first),
                footer: BLETraceDataFixtures.footer(id: second)
            ),
            InvalidBoundary(
                header: BLETraceDataFixtures.header(id: first, startedAt: "invalid"),
                footer: BLETraceDataFixtures.footer(id: first)
            ),
            InvalidBoundary(
                header: BLETraceDataFixtures.header(id: first),
                footer: BLETraceDataFixtures.footer(id: first, endedAt: "1969-12-31T23:59:59.000Z")
            ),
            InvalidBoundary(
                header: BLETraceDataFixtures.header(id: first),
                footer: BLETraceDataFixtures.footer(id: first, eventCount: -1)
            ),
            InvalidBoundary(
                header: BLETraceDataFixtures.header(id: first),
                footer: BLETraceDataFixtures.footer(id: first, status: "unknown")
            )
        ]
    }
}

private struct InvalidBoundary {
    let header: [String: Any]
    let footer: [String: Any]
}
