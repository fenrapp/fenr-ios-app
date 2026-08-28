import Foundation

extension FileBLETraceLogRepository {
    func appendSnapshotFooter(to url: URL, session: ActiveSession) throws {
        let snapshotAt = now()
        let input = FooterInput(
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
        try handle.write(contentsOf: Self.encodeFooter(input, lineEncoder: lineEncoder))
        try handle.synchronize()
    }

    func pruneBeforeStartingSession() throws {
        completedSessions = try Self.prune(
            completedSessions,
            configuration: configuration,
            fileManager: fileManager,
            reservingSessionSlot: true
        )
    }

    func reserveStorageForActiveSession() throws {
        var retainedBytes = completedSessions.reduce(Int64(0)) { $0 + $1.summary.fileSizeBytes }
        while retainedBytes + configuration.terminalRecordReserveBytes
            > configuration.maximumTotalBytes,
            let oldest = completedSessions.last {
            completedSessions.removeLast()
            retainedBytes -= oldest.summary.fileSizeBytes
            try fileManager.removeItem(at: oldest.url)
        }
    }

    func removeExistingExport(for id: UUID) throws {
        guard fileManager.fileExists(atPath: exportDirectory.path) else { return }
        let marker = id.uuidString.lowercased()
        for url in try fileManager.contentsOfDirectory(
            at: exportDirectory,
            includingPropertiesForKeys: nil
        ) where url.lastPathComponent.lowercased().contains(marker) {
            try fileManager.removeItem(at: url)
        }
    }
}
