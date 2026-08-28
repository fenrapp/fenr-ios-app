import AsyncSupport
import BLETraceDomain
import Foundation
public actor FileBLETraceLogRepository: BLETraceRecording, BLETraceLogRepository {
    private let directory: URL
    let exportDirectory: URL
    private let environment: BLETraceEnvironment
    let configuration: BLETraceFileStoreConfiguration
    let fileManager: FileManager
    let lineEncoder: BLETraceJSONLineEncoder
    private let sessionHub: AsyncEventHub<[BLETraceSessionSummary]>
    let now: @Sendable () -> Date
    private let uptimeNanoseconds: @Sendable () -> UInt64
    private var activeSession: ActiveSession?
    var completedSessions: [StoredSession]
    private var pendingLines: [PendingLine] = []
    private var pendingLineIndex = 0
    private var pendingByteCount: Int64 = 0
    private var writerTask: Task<Void, Never>?
    public init(
        directory: URL,
        exportDirectory: URL,
        environment: BLETraceEnvironment,
        configuration: BLETraceFileStoreConfiguration,
        fileManager: FileManager,
        lineEncoder: BLETraceJSONLineEncoder,
        sessionHub: AsyncEventHub<[BLETraceSessionSummary]>,
        now: @escaping @Sendable () -> Date,
        uptimeNanoseconds: @escaping @Sendable () -> UInt64
    ) throws {
        self.directory = directory
        self.exportDirectory = exportDirectory
        self.environment = environment
        self.configuration = configuration
        self.fileManager = fileManager
        self.lineEncoder = lineEncoder
        self.sessionHub = sessionHub
        self.now = now
        self.uptimeNanoseconds = uptimeNanoseconds
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
            try Self.configureDirectory(directory, fileManager: fileManager)
            try Self.configureDirectory(exportDirectory, fileManager: fileManager)
            try Self.recoverPartialFiles(
                in: directory,
                fileManager: fileManager,
                lineEncoder: lineEncoder,
                now: now()
            )
            completedSessions = try Self.loadStoredSessions(in: directory, fileManager: fileManager)
            completedSessions = try Self.prune(
                completedSessions,
                configuration: configuration,
                fileManager: fileManager
            )
        } catch {
            throw BLETraceRepositoryError.unableToCreateStorage
        }
    }
    deinit {
        writerTask?.cancel()
        try? activeSession?.fileHandle.close()
    }
    public func startSession(_ context: BLETraceSessionContext) async {
        if activeSession != nil {
            await finishSession(reason: .clientStopped)
        }
        do {
            try pruneBeforeStartingSession()
            try reserveStorageForActiveSession()
            let fileName = Self.partialFileName(for: context)
            let url = directory.appendingPathComponent(fileName)
            guard fileManager.createFile(atPath: url.path, contents: nil) else {
                return
            }
            try Self.configureLogFile(url, fileManager: fileManager)
            let handle = try FileHandle(forWritingTo: url)
            activeSession = ActiveSession(
                context: context,
                url: url,
                fileHandle: handle,
                nextSequence: 1,
                eventCount: 0,
                bytesWritten: 0,
                isTruncated: false
            )
            let header = HeaderRecord(
                recordType: "header",
                schemaVersion: 1,
                sessionID: context.id,
                startedAt: Self.timestamp(context.startedAt),
                startReason: context.reason.rawValue,
                appVersion: environment.appVersion,
                appBuild: environment.appBuild,
                operatingSystem: environment.operatingSystem,
                deviceModel: environment.deviceModel,
                privacyPolicy: "vin_peripheral_and_authentication_redacted"
            )
            enqueue(try lineEncoder.encode(header), sessionID: context.id)
            await publishSessions()
        } catch {
            closeActiveSessionAfterFailure()
        }
    }

    public func record(_ event: BLETraceEvent) async {
        guard var session = activeSession, !session.isTruncated else { return }
        let record = EventRecord(
            recordType: "event",
            schemaVersion: 1,
            sessionID: session.context.id,
            sequence: session.nextSequence,
            timestamp: Self.timestamp(event.timestamp),
            elapsedMilliseconds: Self.elapsedMilliseconds(
                event.uptimeNanoseconds,
                since: session.context.startUptimeNanoseconds
            ),
            category: event.category,
            operation: event.operation.rawValue,
            direction: event.direction.rawValue,
            serviceUUID: event.serviceUUID,
            characteristicUUID: event.characteristicUUID,
            characteristicProperties: event.characteristicProperties,
            byteCount: event.byteCount,
            payloadHex: event.payloadHex,
            payloadRedacted: event.payloadRedacted,
            decodeStatus: event.decodeStatus?.rawValue,
            readPending: event.readPending,
            detail: event.detail,
            error: event.error
        )
        do {
            let line = try lineEncoder.encode(record)
            let completedBytes = completedSessions.reduce(Int64(0)) { $0 + $1.summary.fileSizeBytes }
            let projectedBytes = completedBytes + session.bytesWritten + pendingByteCount + Int64(line.count)
                + configuration.terminalRecordReserveBytes
            guard projectedBytes <= configuration.maximumTotalBytes else {
                await truncateActiveSession()
                return
            }
            session.nextSequence += 1
            session.eventCount += 1
            activeSession = session
            enqueue(line, sessionID: session.context.id)
        } catch {
            closeActiveSessionAfterFailure()
        }
    }

    public func finishSession(reason: BLETraceSessionEndReason) async {
        guard let session = activeSession else { return }
        await drainPendingLines()
        let endedAt = now()
        let status: BLETraceSessionStatus = session.isTruncated ? .truncated : .complete
        await closeSession(session, endedAt: endedAt, reason: reason, status: status)
    }

    public func observeSessions() async -> AsyncStream<[BLETraceSessionSummary]> {
        await sessionHub.stream(replay: currentSummaries())
    }

    public func prepareExport(sessionID: UUID) async throws -> URL {
        try fileManager.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
        try removeExistingExport(for: sessionID)

        let sourceURL: URL
        let exportName: String
        var activeSnapshot: ActiveSession?
        if activeSession?.context.id == sessionID {
            await drainPendingLines()
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
            try fileManager.copyItem(at: sourceURL, to: destination)
            if let activeSnapshot {
                try appendSnapshotFooter(to: destination, session: activeSnapshot)
            }
            try Self.configureLogFile(destination, fileManager: fileManager)
            return destination
        } catch {
            throw BLETraceRepositoryError.unableToExport
        }
    }

    public func deleteSession(id: UUID) async throws {
        if activeSession?.context.id == id {
            throw BLETraceRepositoryError.activeSessionCannotBeDeleted
        }
        guard let index = completedSessions.firstIndex(where: { $0.summary.id == id }) else {
            throw BLETraceRepositoryError.sessionNotFound
        }
        let stored = completedSessions.remove(at: index)
        try fileManager.removeItem(at: stored.url)
        try? removeExistingExport(for: id)
        await publishSessions()
    }

    public func deleteAllSessions() async throws {
        for stored in completedSessions {
            try fileManager.removeItem(at: stored.url)
        }
        completedSessions.removeAll()
        if fileManager.fileExists(atPath: exportDirectory.path) {
            try fileManager.removeItem(at: exportDirectory)
            try fileManager.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
            try Self.configureDirectory(exportDirectory, fileManager: fileManager)
        }
        await publishSessions()
    }
}

private extension FileBLETraceLogRepository {
    func enqueue(_ data: Data, sessionID: UUID) {
        pendingLines.append(PendingLine(sessionID: sessionID, data: data))
        pendingByteCount += Int64(data.count)
        guard writerTask == nil else { return }
        writerTask = Task { [weak self] in
            await self?.drainPendingLines()
        }
    }

    func drainPendingLines() async {
        while pendingLineIndex < pendingLines.count {
            guard !Task.isCancelled else { break }
            let pending = pendingLines[pendingLineIndex]
            pendingLineIndex += 1
            pendingByteCount -= Int64(pending.data.count)
            guard var session = activeSession, session.context.id == pending.sessionID else { continue }
            do {
                try session.fileHandle.write(contentsOf: pending.data)
                session.bytesWritten += Int64(pending.data.count)
                activeSession = session
            } catch {
                closeActiveSessionAfterFailure()
                break
            }
            await Task.yield()
        }
        if pendingLineIndex >= pendingLines.count {
            pendingLines.removeAll(keepingCapacity: true)
            pendingLineIndex = 0
            pendingByteCount = 0
        }
        writerTask = nil
    }

    func truncateActiveSession() async {
        guard var session = activeSession else { return }
        session.isTruncated = true
        activeSession = session
        let marker = EventRecord(
            recordType: "event",
            schemaVersion: 1,
            sessionID: session.context.id,
            sequence: session.nextSequence,
            timestamp: Self.timestamp(now()),
            elapsedMilliseconds: Self.elapsedMilliseconds(
                uptimeNanoseconds(),
                since: session.context.startUptimeNanoseconds
            ),
            category: "storage",
            operation: BLETraceOperation.captureTruncated.rawValue,
            direction: BLETraceDirection.internalEvent.rawValue,
            serviceUUID: nil,
            characteristicUUID: nil,
            characteristicProperties: nil,
            byteCount: nil,
            payloadHex: nil,
            payloadRedacted: false,
            decodeStatus: nil,
            readPending: nil,
            detail: "Trace stopped after reaching the configured storage limit",
            error: nil
        )
        if let line = try? lineEncoder.encode(marker) {
            enqueue(line, sessionID: session.context.id)
            session.nextSequence += 1
            session.eventCount += 1
            activeSession = session
        }
        await drainPendingLines()
        await closeSession(
            session,
            endedAt: now(),
            reason: .storageLimitReached,
            status: .truncated
        )
    }

    func closeSession(
        _ originalSession: ActiveSession,
        endedAt: Date,
        reason: BLETraceSessionEndReason,
        status: BLETraceSessionStatus
    ) async {
        guard var session = activeSession, session.context.id == originalSession.context.id else { return }
        let durationMilliseconds = max(
            0,
            Int64(endedAt.timeIntervalSince(session.context.startedAt) * 1_000)
        )
        let footerInput = FooterInput(
            sessionID: session.context.id,
            endedAt: endedAt,
            durationMilliseconds: durationMilliseconds,
            eventCount: session.eventCount,
            baseBytes: session.bytesWritten,
            status: status,
            reason: reason
        )
        if let data = try? Self.encodeFooter(footerInput, lineEncoder: lineEncoder) {
            try? session.fileHandle.write(contentsOf: data)
            session.bytesWritten += Int64(data.count)
        }
        try? session.fileHandle.synchronize()
        try? session.fileHandle.close()

        let finalURL = session.url.deletingPathExtension().appendingPathExtension("jsonl")
        do {
            if fileManager.fileExists(atPath: finalURL.path) {
                try fileManager.removeItem(at: finalURL)
            }
            try fileManager.moveItem(at: session.url, to: finalURL)
            let summary = BLETraceSessionSummary(
                id: session.context.id,
                startedAt: session.context.startedAt,
                endedAt: endedAt,
                duration: endedAt.timeIntervalSince(session.context.startedAt),
                fileSizeBytes: Self.fileSize(finalURL, fileManager: fileManager),
                eventCount: session.eventCount,
                status: status,
                fileName: finalURL.lastPathComponent
            )
            completedSessions.insert(StoredSession(summary: summary, url: finalURL), at: 0)
            completedSessions = try Self.prune(
                completedSessions,
                configuration: configuration,
                fileManager: fileManager
            )
        } catch {
            // The partial file remains recoverable on the next launch.
        }
        activeSession = nil
        await publishSessions()
    }

    func closeActiveSessionAfterFailure() {
        writerTask?.cancel()
        writerTask = nil
        pendingLines.removeAll()
        pendingLineIndex = 0
        pendingByteCount = 0
        try? activeSession?.fileHandle.close()
        activeSession = nil
    }

    func currentSummaries() -> [BLETraceSessionSummary] {
        let activeSummary: [BLETraceSessionSummary]
        if let activeSession {
            activeSummary = [BLETraceSessionSummary(
                id: activeSession.context.id,
                startedAt: activeSession.context.startedAt,
                endedAt: nil,
                duration: nil,
                fileSizeBytes: activeSession.bytesWritten + pendingByteCount,
                eventCount: activeSession.eventCount,
                status: .active,
                fileName: activeSession.url.deletingPathExtension().lastPathComponent + ".jsonl"
            )]
        } else {
            activeSummary = []
        }
        return Array((activeSummary + completedSessions.map(\.summary)).prefix(configuration.maximumSessionCount))
    }

    func publishSessions() async {
        await sessionHub.send(currentSummaries())
    }

}
