import BLETraceData
import BLETraceDomain
import Foundation
import Testing

@Suite("BLE trace file repository")
struct FileBLETraceLogRepositoryTests {
    @Test("Writes ordered NDJSON and exports active and completed sessions")
    func writesAndExportsSessions() async throws {
        let context = try makeBLETraceDataTestContext()
        defer { try? FileManager.default.removeItem(at: context.directory.deletingLastPathComponent()) }
        let session = makeTraceContext()

        await context.repository.startSession(session)
        await context.repository.record(makeTraceEvent(index: 1))
        await context.repository.record(makeTraceEvent(index: 2))

        let activeExport = try await context.repository.prepareExport(sessionID: session.id)
        let activeRecords = try records(at: activeExport)
        let activeExportBytes = try Data(contentsOf: activeExport).count
        #expect(activeRecords.first?["record_type"] as? String == "header")
        #expect(activeRecords.filter { $0["record_type"] as? String == "event" }.count == 2)
        #expect(activeRecords.last?["record_type"] as? String == "footer")
        #expect(activeRecords.last?["status"] as? String == "active")
        #expect(activeRecords.last?["reason"] as? String == "export_snapshot")
        #expect(activeRecords.last?["bytes"] as? Int == activeExportBytes)
        await context.repository.record(makeTraceEvent(index: 3))
        #expect(try records(at: activeExport).count == activeRecords.count)

        await context.repository.finishSession(reason: .userDisconnected)
        let completedExport = try await context.repository.prepareExport(sessionID: session.id)
        let records = try records(at: completedExport)
        let completedExportBytes = try Data(contentsOf: completedExport).count
        #expect(records.last?["record_type"] as? String == "footer")
        #expect(records.last?["status"] as? String == "complete")
        #expect(records.last?["bytes"] as? Int == completedExportBytes)
        #expect(records.compactMap { $0["sequence"] as? Int } == [1, 2, 3])
    }

    @Test("Retains only the configured number of newest sessions")
    func prunesOldSessions() async throws {
        let context = try makeBLETraceDataTestContext(maximumSessionCount: 2)
        defer { try? FileManager.default.removeItem(at: context.directory.deletingLastPathComponent()) }

        for index in 0 ..< 3 {
            let session = makeTraceContext(startedAt: Date(timeIntervalSince1970: Double(index)))
            await context.repository.startSession(session)
            await context.repository.record(makeTraceEvent(index: index))
            await context.repository.finishSession(reason: .userDisconnected)
        }

        let stream = await context.repository.observeSessions()
        let sessions = await stream.first(where: { !$0.isEmpty }) ?? []
        #expect(sessions.count == 2)
        #expect(sessions.map(\.startedAt) == [
            Date(timeIntervalSince1970: 2),
            Date(timeIntervalSince1970: 1)
        ])
    }

    @Test("Marks a session truncated when the storage limit is reached")
    func truncatesAtStorageLimit() async throws {
        let context = try makeBLETraceDataTestContext(maximumTotalBytes: 1_200)
        defer { try? FileManager.default.removeItem(at: context.directory.deletingLastPathComponent()) }
        let session = makeTraceContext()

        await context.repository.startSession(session)
        await context.repository.record(makeTraceEvent(index: 1, detail: String(repeating: "x", count: 2_000)))

        let stream = await context.repository.observeSessions()
        let sessions = await stream.first(where: { !$0.isEmpty }) ?? []
        #expect(sessions.first?.status == .truncated)
        let export = try await context.repository.prepareExport(sessionID: session.id)
        #expect(try records(at: export).last?["status"] as? String == "truncated")
    }

    @Test("Recovers partial files as incomplete sessions")
    func recoversPartialFiles() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let logs = root.appendingPathComponent("logs", isDirectory: true)
        try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        let id = UUID()
        let partial = logs.appendingPathComponent("interrupted.partial")
        let header: [String: Any] = [
            "record_type": "header",
            "schema_version": 1,
            "session_id": id.uuidString,
            "started_at": "1970-01-01T00:00:10.000Z"
        ]
        let event: [String: Any] = [
            "record_type": "event",
            "schema_version": 1,
            "session_id": id.uuidString,
            "sequence": 1
        ]
        var interruptedData = try JSONSerialization.data(withJSONObject: header)
        interruptedData.append(0x0A)
        interruptedData.append(try JSONSerialization.data(withJSONObject: event))
        interruptedData.append(0x0A)
        try interruptedData.write(to: partial)

        let context = try makeBLETraceDataTestContext(root: root)
        let stream = await context.repository.observeSessions()
        let sessions = await stream.first(where: { !$0.isEmpty }) ?? []
        #expect(sessions.first?.id == id)
        #expect(sessions.first?.status == .incomplete)
        let export = try await context.repository.prepareExport(sessionID: id)
        #expect(try records(at: export).last?["reason"] as? String == "abrupt_termination")
    }

    @Test("Protects the active session from deletion")
    func protectsActiveSession() async throws {
        let context = try makeBLETraceDataTestContext()
        defer { try? FileManager.default.removeItem(at: context.directory.deletingLastPathComponent()) }
        let session = makeTraceContext()
        await context.repository.startSession(session)

        await #expect(throws: BLETraceRepositoryError.activeSessionCannotBeDeleted) {
            try await context.repository.deleteSession(id: session.id)
        }
    }

    @Test("Reports unavailable storage during initialization")
    func reportsStorageInitializationFailure() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data([0x01]).write(to: root)

        #expect(throws: BLETraceRepositoryError.unableToCreateStorage) {
            _ = try makeBLETraceDataTestContext(root: root)
        }
    }

    private func records(at url: URL) throws -> [[String: Any]] {
        let data = try Data(contentsOf: url)
        return try data.split(separator: 0x0A).map {
            try #require(JSONSerialization.jsonObject(with: Data($0)) as? [String: Any])
        }
    }
}
