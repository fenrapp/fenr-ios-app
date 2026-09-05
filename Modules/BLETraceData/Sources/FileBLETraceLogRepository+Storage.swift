import BLETraceDomain
import Foundation

extension FileBLETraceLogRepository {
    static func prepareDirectories(
        directory: URL,
        exportDirectory: URL,
        fileManager: FileManager
    ) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
        try configureDirectory(directory, fileManager: fileManager)
        try configureDirectory(exportDirectory, fileManager: fileManager)
    }

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

    static func fileSize(_ url: URL, fileManager: FileManager) -> Int64 {
        let attributes = try? fileManager.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
    }

    static func removeItemIfPresent(_ url: URL, fileManager: FileManager) throws {
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    static func removeDirectoryContents(_ directory: URL, fileManager: FileManager) throws {
        guard fileManager.fileExists(atPath: directory.path) else { return }
        for url in try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) {
            try fileManager.removeItem(at: url)
        }
    }

    static func removeExactExport(
        named fileName: String,
        exportDirectory: URL,
        fileManager: FileManager
    ) throws {
        try removeItemIfPresent(
            exportDirectory.appendingPathComponent(fileName),
            fileManager: fileManager
        )
    }

    static func recoverPartialFiles(
        in directory: URL,
        fileManager: FileManager,
        codec: BLETraceRecordCodec,
        now: Date
    ) throws {
        let urls = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        for url in urls where url.pathExtension == "partial" {
            guard let firstLine = try? firstJSONLine(at: url),
                  let header = codec.decodeHeaderBoundary(firstLine) else { continue }
            do {
                let finalURL = url.deletingPathExtension().appendingPathExtension("jsonl")
                guard !fileManager.fileExists(atPath: finalURL.path) else { continue }
                let lastLine = try lastJSONLine(at: url)
                let hasValidFooter = lastLine.flatMap {
                    codec.decodeSessionBoundary(headerData: firstLine, footerData: $0)
                } != nil
                if !hasValidFooter {
                    let fileStatistics = try streamStatistics(at: url)
                    let eventCount = max(0, fileStatistics.recordCount - 1)
                    let endedAt = max(now, header.startedAt)
                    let footerInput = BLETraceRecordCodec.FooterInput(
                        sessionID: header.sessionID,
                        endedAt: endedAt,
                        durationMilliseconds: max(
                            0,
                            Int64(endedAt.timeIntervalSince(header.startedAt) * 1_000)
                        ),
                        eventCount: eventCount,
                        baseBytes: fileStatistics.byteCount,
                        status: .incomplete,
                        reason: .abruptTermination
                    )
                    let handle = try FileHandle(forWritingTo: url)
                    do {
                        _ = try handle.seekToEnd()
                        try handle.write(contentsOf: codec.encodeFooter(footerInput))
                        try handle.synchronize()
                        try handle.close()
                    } catch {
                        try? handle.close()
                        throw error
                    }
                }
                try configureLogFile(url, fileManager: fileManager)
                try fileManager.moveItem(at: url, to: finalURL)
                try configureLogFile(finalURL, fileManager: fileManager)
            } catch {
                // Keep the partial file for a future recovery attempt.
            }
        }
    }

    static func loadStoredSessions(
        in directory: URL,
        fileManager: FileManager,
        codec: BLETraceRecordCodec
    ) throws -> [StoredSession] {
        let urls = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "jsonl" || $0.pathExtension == "partial" }
        return urls.compactMap { url in
            if url.pathExtension == "partial" {
                let finalURL = url.deletingPathExtension().appendingPathExtension("jsonl")
                guard !fileManager.fileExists(atPath: finalURL.path) else { return nil }
                return incompleteSession(at: url, fileManager: fileManager, codec: codec)
            }
            guard let first = try? firstJSONLine(at: url),
                  let last = try? lastJSONLine(at: url),
                  let boundary = codec.decodeSessionBoundary(headerData: first, footerData: last)
            else { return nil }
            guard (try? configureLogFile(url, fileManager: fileManager)) != nil else { return nil }
            return StoredSession(
                summary: BLETraceSessionSummary(
                    id: boundary.sessionID,
                    startedAt: boundary.startedAt,
                    endedAt: boundary.endedAt,
                    duration: boundary.endedAt.timeIntervalSince(boundary.startedAt),
                    fileSizeBytes: fileSize(url, fileManager: fileManager),
                    eventCount: boundary.eventCount,
                    status: boundary.status,
                    fileName: url.lastPathComponent
                ),
                url: url
            )
        }
        .sorted(by: storedSessionPrecedes)
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
        exportDirectory: URL,
        reservingSessionSlot: Bool = false
    ) throws -> [StoredSession] {
        var retained = sessions.sorted(by: storedSessionPrecedes)
        let countLimit = max(0, configuration.maximumSessionCount - (reservingSessionSlot ? 1 : 0))
        while retained.count > countLimit {
            let removed = retained.removeLast()
            try removeExactExport(
                named: removed.summary.fileName,
                exportDirectory: exportDirectory,
                fileManager: fileManager
            )
            try fileManager.removeItem(at: removed.url)
        }
        var total = retained.reduce(Int64(0)) { $0 + $1.summary.fileSizeBytes }
        while total > configuration.maximumTotalBytes, let removed = retained.last {
            try removeExactExport(
                named: removed.summary.fileName,
                exportDirectory: exportDirectory,
                fileManager: fileManager
            )
            retained.removeLast()
            total -= removed.summary.fileSizeBytes
            try fileManager.removeItem(at: removed.url)
        }
        return retained
    }

    static func storedSessionPrecedes(_ lhs: StoredSession, _ rhs: StoredSession) -> Bool {
        if lhs.summary.startedAt != rhs.summary.startedAt {
            return lhs.summary.startedAt > rhs.summary.startedAt
        }
        return lhs.summary.id.uuidString < rhs.summary.id.uuidString
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
