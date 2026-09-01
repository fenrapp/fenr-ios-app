import BLETraceDomain
import Foundation

extension FileBLETraceLogRepository {
    public func prepareExport(sessionID: UUID) async throws -> URL {
        try Task.checkCancellation()
        await prepareStorage()
        try Task.checkCancellation()
        guard hasPreparedStorage else { throw BLETraceRepositoryError.unableToExport }

        let sourceURL: URL
        let exportName: String
        var activeSnapshot: ActiveSession?
        if activeSession?.context.id == sessionID {
            await drainPendingLines()
            try Task.checkCancellation()
            guard let session = activeSession, session.context.id == sessionID else {
                throw BLETraceRepositoryError.sessionNotFound
            }
            try session.fileHandle.synchronize()
            activeSnapshot = session
            sourceURL = session.url
            exportName = session.url.deletingPathExtension().lastPathComponent + ".jsonl"
        } else if let stored = completedSessions.first(where: { $0.summary.id == sessionID }) {
            sourceURL = stored.url
            exportName = stored.summary.fileName
        } else {
            throw BLETraceRepositoryError.sessionNotFound
        }

        let destination = exportDirectory.appendingPathComponent(exportName)
        do {
            try Task.checkCancellation()
            try Self.removeItemIfPresent(destination, fileManager: fileManager)
            try fileManager.copyItem(at: sourceURL, to: destination)
            try Task.checkCancellation()
            if let activeSnapshot {
                try appendSnapshotFooter(to: destination, session: activeSnapshot)
            }
            try Task.checkCancellation()
            try Self.configureLogFile(destination, fileManager: fileManager)
            return destination
        } catch is CancellationError {
            try? Self.removeItemIfPresent(destination, fileManager: fileManager)
            throw CancellationError()
        } catch {
            try? Self.removeItemIfPresent(destination, fileManager: fileManager)
            throw BLETraceRepositoryError.unableToExport
        }
    }

    public func deleteSession(id: UUID) async throws {
        try Task.checkCancellation()
        await prepareStorage()
        try Task.checkCancellation()
        if activeSession?.context.id == id {
            throw BLETraceRepositoryError.activeSessionCannotBeDeleted
        }
        guard let stored = completedSessions.first(where: { $0.summary.id == id }) else {
            throw BLETraceRepositoryError.sessionNotFound
        }
        do {
            try Self.removeExactExport(
                named: stored.summary.fileName,
                exportDirectory: exportDirectory,
                fileManager: fileManager
            )
            try fileManager.removeItem(at: stored.url)
        } catch {
            reconcileCompletedSessionsFromDisk()
            throw error
        }
        reconcileCompletedSessionsFromDisk()
        await publishSessions()
    }

    public func deleteAllSessions() async throws {
        try Task.checkCancellation()
        await prepareStorage()
        try Task.checkCancellation()
        do {
            for stored in completedSessions {
                try Self.removeExactExport(
                    named: stored.summary.fileName,
                    exportDirectory: exportDirectory,
                    fileManager: fileManager
                )
                try fileManager.removeItem(at: stored.url)
            }
            try Self.removeDirectoryContents(exportDirectory, fileManager: fileManager)
        } catch {
            reconcileCompletedSessionsFromDisk()
            throw error
        }
        reconcileCompletedSessionsFromDisk()
        await publishSessions()
    }

    func appendSnapshotFooter(to url: URL, session: ActiveSession) throws {
        let snapshotAt = now()
        let input = BLETraceRecordCodec.FooterInput(
            sessionID: session.context.id,
            endedAt: snapshotAt,
            durationMilliseconds: max(
                0,
                Int64(snapshotAt.timeIntervalSince(session.context.startedAt) * 1_000)
            ),
            eventCount: session.eventCount,
            baseBytes: Self.fileSize(url, fileManager: fileManager),
            status: .active,
            reason: .exportSnapshot
        )
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        _ = try handle.seekToEnd()
        try handle.write(contentsOf: recordCodec.encodeFooter(input))
        try handle.synchronize()
    }

    func pruneBeforeStartingSession() throws {
        do {
            completedSessions = try Self.prune(
                completedSessions,
                configuration: configuration,
                fileManager: fileManager,
                exportDirectory: exportDirectory,
                reservingSessionSlot: true
            )
        } catch {
            reconcileCompletedSessionsFromDisk()
            throw error
        }
    }

    func reserveStorageForActiveSession() throws {
        var retainedBytes = completedSessions.reduce(Int64(0)) { $0 + $1.summary.fileSizeBytes }
        while retainedBytes + configuration.terminalRecordReserveBytes
            > configuration.maximumTotalBytes,
            let oldest = completedSessions.last {
            completedSessions.removeLast()
            retainedBytes -= oldest.summary.fileSizeBytes
            do {
                try Self.removeExactExport(
                    named: oldest.summary.fileName,
                    exportDirectory: exportDirectory,
                    fileManager: fileManager
                )
                try fileManager.removeItem(at: oldest.url)
            } catch {
                reconcileCompletedSessionsFromDisk()
                throw error
            }
        }
    }
}
