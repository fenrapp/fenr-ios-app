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
            guard let firstLine = try? firstJSONLine(at: url),
                  let header = try? JSONSerialization.jsonObject(with: firstLine) as? [String: Any],
                  let rawID = header["session_id"] as? String,
                  let id = UUID(uuidString: rawID),
                  let rawStart = header["started_at"] as? String,
                  let startedAt = try? Date(rawStart, strategy: .iso8601)
            else {
                continue
            }
            let fileStatistics = try streamStatistics(at: url)
            let eventCount = max(0, fileStatistics.recordCount - 1)
            let footerInput = FooterInput(
                sessionID: id,
                endedAt: now,
                durationMilliseconds: max(0, Int64(now.timeIntervalSince(startedAt) * 1_000)),
                eventCount: eventCount,
                baseBytes: fileStatistics.byteCount,
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
            guard let first = try? firstJSONLine(at: url),
                  let last = try? lastJSONLine(at: url),
                  let header = try? JSONSerialization.jsonObject(with: first) as? [String: Any],
                  let footer = try? JSONSerialization.jsonObject(with: last) as? [String: Any],
                  let rawID = header["session_id"] as? String,
                  let id = UUID(uuidString: rawID),
                  let rawStart = header["started_at"] as? String,
                  let startedAt = try? Date(rawStart, strategy: .iso8601),
                  let rawEnd = footer["ended_at"] as? String,
                  let endedAt = try? Date(rawEnd, strategy: .iso8601),
                  let rawStatus = footer["status"] as? String,
                  let status = BLETraceSessionStatus(rawValue: rawStatus)
            else { return nil }
            let eventCount = footer["event_count"] as? Int ?? 0
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

    static func firstJSONLine(at url: URL) throws -> Data? {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: Constants.maximumBoundaryRecordBytes) ?? Data()
        guard !data.isEmpty else { return nil }
        if let newline = data.firstIndex(of: Constants.newline) {
            return Data(data[..<newline])
        }
        guard data.count < Constants.maximumBoundaryRecordBytes else { return nil }
        return data
    }

    static func lastJSONLine(at url: URL) throws -> Data? {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let fileLength = try handle.seekToEnd()
        guard fileLength > 0 else { return nil }
        let readLength = min(UInt64(Constants.maximumBoundaryRecordBytes), fileLength)
        try handle.seek(toOffset: fileLength - readLength)
        var data = try handle.read(upToCount: Int(readLength)) ?? Data()
        while data.last == Constants.newline || data.last == Constants.carriageReturn {
            data.removeLast()
        }
        guard !data.isEmpty else { return nil }
        if let newline = data.lastIndex(of: Constants.newline) {
            return Data(data[data.index(after: newline)...])
        }
        guard readLength == fileLength else { return nil }
        return data
    }

    static func streamStatistics(at url: URL) throws -> FileStreamStatistics {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var byteCount: Int64 = 0
        var newlineCount = 0
        var lastByte: UInt8?
        while let block = try handle.read(upToCount: Constants.streamingBlockBytes), !block.isEmpty {
            byteCount += Int64(block.count)
            newlineCount += block.reduce(into: 0) { count, byte in
                if byte == Constants.newline { count += 1 }
            }
            lastByte = block.last
        }
        let recordCount = newlineCount + ((lastByte != nil && lastByte != Constants.newline) ? 1 : 0)
        return FileStreamStatistics(byteCount: byteCount, recordCount: recordCount)
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

    struct FileStreamStatistics {
        let byteCount: Int64
        let recordCount: Int
    }

    enum Constants {
        static let newline: UInt8 = 0x0A
        static let carriageReturn: UInt8 = 0x0D
        static let maximumBoundaryRecordBytes = 64 * 1_024
        static let streamingBlockBytes = 64 * 1_024
    }
}
