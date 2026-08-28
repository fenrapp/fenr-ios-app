import BLETraceDomain
import Foundation

extension FileBLETraceLogRepository {
    static func configureDirectory(_ url: URL, fileManager: FileManager) throws {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = url
        try mutableURL.setResourceValues(values)
        try fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
    }

    static func configureLogFile(_ url: URL, fileManager: FileManager) throws {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = url
        try mutableURL.setResourceValues(values)
        try fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
    }

    static func partialFileName(for context: BLETraceSessionContext) -> String {
        "fenr-ble-\(Int(context.startedAt.timeIntervalSince1970))-"
            + "\(context.id.uuidString.lowercased()).partial"
    }

    static func timestamp(_ date: Date) -> String {
        Date.ISO8601FormatStyle(includingFractionalSeconds: true, timeZone: .gmt).format(date)
    }

    static func elapsedMilliseconds(_ uptime: UInt64, since start: UInt64) -> Int64 {
        guard uptime >= start else { return 0 }
        return Int64((uptime - start) / 1_000_000)
    }

    static func fileSize(_ url: URL, fileManager: FileManager) -> Int64 {
        let attributes = try? fileManager.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
    }

    static func recoverPartialFiles(
        in directory: URL,
        fileManager: FileManager,
        lineEncoder: BLETraceJSONLineEncoder,
        now: Date
    ) throws {
        let urls = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        for url in urls where url.pathExtension == "partial" {
            guard let data = try? Data(contentsOf: url),
                  let firstLine = data.split(separator: 0x0A).first,
                  let header = try? JSONSerialization.jsonObject(with: Data(firstLine)) as? [String: Any],
                  let rawID = header["session_id"] as? String,
                  let id = UUID(uuidString: rawID),
                  let rawStart = header["started_at"] as? String,
                  let startedAt = try? Date(rawStart, strategy: .iso8601)
            else {
                continue
            }
            let eventCount = max(0, data.split(separator: 0x0A).count - 1)
            let footerInput = FooterInput(
                sessionID: id,
                endedAt: now,
                durationMilliseconds: max(0, Int64(now.timeIntervalSince(startedAt) * 1_000)),
                eventCount: eventCount,
                baseBytes: Int64(data.count),
                status: .incomplete,
                reason: .abruptTermination
            )
            if let handle = try? FileHandle(forWritingTo: url) {
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: encodeFooter(footerInput, lineEncoder: lineEncoder))
                try? handle.close()
            }
            let finalURL = url.deletingPathExtension().appendingPathExtension("jsonl")
            if fileManager.fileExists(atPath: finalURL.path) {
                try fileManager.removeItem(at: finalURL)
            }
            try fileManager.moveItem(at: url, to: finalURL)
        }
    }

    static func loadStoredSessions(in directory: URL, fileManager: FileManager) throws -> [StoredSession] {
        let urls = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "jsonl" }
        return urls.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            let lines = data.split(separator: 0x0A)
            guard let first = lines.first,
                  let last = lines.last,
                  let header = try? JSONSerialization.jsonObject(with: Data(first)) as? [String: Any],
                  let footer = try? JSONSerialization.jsonObject(with: Data(last)) as? [String: Any],
                  let rawID = header["session_id"] as? String,
                  let id = UUID(uuidString: rawID),
                  let rawStart = header["started_at"] as? String,
                  let startedAt = try? Date(rawStart, strategy: .iso8601),
                  let rawEnd = footer["ended_at"] as? String,
                  let endedAt = try? Date(rawEnd, strategy: .iso8601),
                  let rawStatus = footer["status"] as? String,
                  let status = BLETraceSessionStatus(rawValue: rawStatus)
            else { return nil }
            let eventCount = footer["event_count"] as? Int ?? max(0, lines.count - 2)
            return StoredSession(
                summary: BLETraceSessionSummary(
                    id: id,
                    startedAt: startedAt,
                    endedAt: endedAt,
                    duration: endedAt.timeIntervalSince(startedAt),
                    fileSizeBytes: fileSize(url, fileManager: fileManager),
                    eventCount: eventCount,
                    status: status,
                    fileName: url.lastPathComponent
                ),
                url: url
            )
        }
        .sorted { $0.summary.startedAt > $1.summary.startedAt }
    }

    static func prune(
        _ sessions: [StoredSession],
        configuration: BLETraceFileStoreConfiguration,
        fileManager: FileManager,
        reservingSessionSlot: Bool = false
    ) throws -> [StoredSession] {
        var retained = sessions.sorted { $0.summary.startedAt > $1.summary.startedAt }
        let countLimit = max(0, configuration.maximumSessionCount - (reservingSessionSlot ? 1 : 0))
        while retained.count > countLimit {
            let removed = retained.removeLast()
            try fileManager.removeItem(at: removed.url)
        }
        var total = retained.reduce(Int64(0)) { $0 + $1.summary.fileSizeBytes }
        while total > configuration.maximumTotalBytes, retained.count > 1 {
            let removed = retained.removeLast()
            total -= removed.summary.fileSizeBytes
            try fileManager.removeItem(at: removed.url)
        }
        return retained
    }
}
