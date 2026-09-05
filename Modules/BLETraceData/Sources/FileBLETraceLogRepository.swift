import AsyncSupport
import BLETraceDomain
import Foundation
public actor FileBLETraceLogRepository: BLETraceRecording, BLETraceLogRepository {
    let captureState: BLETraceCaptureState
    let directory: URL
    let exportDirectory: URL
    private let environment: BLETraceEnvironment
    let configuration: BLETraceFileStoreConfiguration
    let fileManager: FileManager
    let recordCodec: BLETraceRecordCodec
    let writerTaskStarter: any BLETraceWriterTaskStarter
    let failureHub: AsyncEventHub<BLETraceRecordingFailure?>
    var recordingFailure: BLETraceRecordingFailure?
    private let sessionHub: AsyncEventHub<[BLETraceSessionSummary]>
    let now: @Sendable () -> Date
    private let uptimeNanoseconds: @Sendable () -> UInt64
    var activeSession: ActiveSession?
    var completedSessions: [StoredSession]
    var hasPreparedStorage = false
    private var pendingLines: [PendingLine] = []
    private var pendingLineIndex = 0
    private var pendingByteCount: Int64 = 0
    private var writerTask: Task<Void, Never>?
    private var writerTaskID: UUID?

    public static func make(
        directory: URL,
        exportDirectory: URL,
        environment: BLETraceEnvironment,
        configuration: BLETraceFileStoreConfiguration,
        dependencies: sending BLETraceFileStoreDependencies
    ) -> FileBLETraceLogRepository {
        FileBLETraceLogRepository(
            captureState: dependencies.captureState,
            directory: directory,
            exportDirectory: exportDirectory,
            environment: environment,
            configuration: configuration,
            fileManager: dependencies.fileManager,
            recordCodec: BLETraceRecordCodec(
                lineEncoder: dependencies.lineEncoder,
                boundaryDecoder: .init()
            ),
            sessionHub: dependencies.sessionHub,
            failureHub: dependencies.failureHub,
            now: dependencies.now,
            uptimeNanoseconds: dependencies.uptimeNanoseconds,
            writerTaskStarter: dependencies.writerTaskStarter
        )
    }

    init(
        captureState: BLETraceCaptureState,
        directory: URL,
        exportDirectory: URL,
        environment: BLETraceEnvironment,
        configuration: BLETraceFileStoreConfiguration,
        fileManager: FileManager,
        recordCodec: BLETraceRecordCodec,
        sessionHub: AsyncEventHub<[BLETraceSessionSummary]>,
        failureHub: AsyncEventHub<BLETraceRecordingFailure?>,
        now: @escaping @Sendable () -> Date,
        uptimeNanoseconds: @escaping @Sendable () -> UInt64,
        writerTaskStarter: any BLETraceWriterTaskStarter
    ) {
        self.captureState = captureState
        self.directory = directory
        self.exportDirectory = exportDirectory
        self.environment = environment
        self.configuration = configuration
        self.fileManager = fileManager
        self.recordCodec = recordCodec
        self.sessionHub = sessionHub
        self.failureHub = failureHub
        self.now = now
        self.uptimeNanoseconds = uptimeNanoseconds
        self.writerTaskStarter = writerTaskStarter
        completedSessions = []
    }
    deinit {
        captureState.setRecording(false)
        writerTask?.cancel()
        try? activeSession?.fileHandle.close()
    }

    @discardableResult
    public func startSession(_ context: BLETraceSessionContext) async -> Bool {
        await prepareStorage()
        guard hasPreparedStorage else {
            await reportRecordingFailure(sessionID: context.id, phase: .opening)
            return false
        }
        if activeSession != nil {
            guard await finishSession(reason: .clientStopped) else { return false }
        }
        do {
            try pruneBeforeStartingSession()
            try reserveStorageForActiveSession()
            let fileName = Self.partialFileName(for: context)
            let url = directory.appendingPathComponent(fileName)
            guard fileManager.createFile(atPath: url.path, contents: nil) else {
                throw BLETraceRepositoryError.unableToCreateStorage
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
            let header = try recordCodec.encodeHeader(context: context, environment: environment)
            try handle.write(contentsOf: header)
            try handle.synchronize()
            activeSession?.bytesWritten = Int64(header.count)
            captureState.setRecording(true)
            recordingFailure = nil
            await failureHub.send(nil)
            await publishSessions()
            return activeSession?.context.id == context.id
        } catch {
            await closeActiveSessionAfterFailure(sessionID: context.id, phase: .opening)
            return false
        }
    }

    public func record(_ event: BLETraceEvent) async {
        guard captureState.isRecording, var session = activeSession, !session.isTruncated else { return }
        do {
            let line = try recordCodec.encodeEvent(
                event,
                sessionID: session.context.id,
                sequence: session.nextSequence,
                startUptimeNanoseconds: session.context.startUptimeNanoseconds
            )
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
            await closeActiveSessionAfterFailure(phase: .writing)
        }
    }

    @discardableResult
    public func finishSession(reason: BLETraceSessionEndReason) async -> Bool {
        captureState.setRecording(false)
        guard let session = activeSession else { return recordingFailure == nil }
        await drainPendingLines()
        guard activeSession?.context.id == session.context.id else { return false }
        let endedAt = now()
        let status: BLETraceSessionStatus = session.isTruncated ? .truncated : .complete
        return await closeSession(session, endedAt: endedAt, reason: reason, status: status)
    }

    public func observeSessions() async -> AsyncStream<[BLETraceSessionSummary]> {
        await prepareStorage()
        return await sessionHub.stream(replay: currentSummaries())
    }

}

extension FileBLETraceLogRepository {
    func enqueue(_ data: Data, sessionID: UUID) {
        pendingLines.append(PendingLine(sessionID: sessionID, data: data))
        pendingByteCount += Int64(data.count)
        guard writerTask == nil else { return }
        let taskID = UUID()
        writerTaskID = taskID
        writerTask = writerTaskStarter.start { [weak self] in
            await self?.drainPendingLines(writerTaskID: taskID)
        }
    }

    func drainPendingLines() async {
        writerTask?.cancel()
        writerTask = nil
        writerTaskID = nil
        await writePendingLines(writerTaskID: nil)
    }

    func drainPendingLines(writerTaskID taskID: UUID) async {
        guard writerTaskID == taskID else { return }
        await writePendingLines(writerTaskID: taskID)
        guard writerTaskID == taskID else { return }
        writerTask = nil
        writerTaskID = nil
    }

    func writePendingLines(writerTaskID taskID: UUID?) async {
        while pendingLineIndex < pendingLines.count {
            if let taskID, writerTaskID != taskID { return }
            let pending = pendingLines[pendingLineIndex]
            pendingLineIndex += 1
            pendingByteCount -= Int64(pending.data.count)
            guard var session = activeSession, session.context.id == pending.sessionID else { continue }
            do {
                try session.fileHandle.write(contentsOf: pending.data)
                session.bytesWritten += Int64(pending.data.count)
                activeSession = session
            } catch {
                await closeActiveSessionAfterFailure(phase: .writing)
                break
            }
            await Task.yield()
        }
        if pendingLineIndex >= pendingLines.count {
            pendingLines.removeAll(keepingCapacity: true)
            pendingLineIndex = 0
            pendingByteCount = 0
        }
    }

    func truncateActiveSession() async {
        guard var session = activeSession else { return }
        session.isTruncated = true
        activeSession = session
        if let line = try? recordCodec.encodeStorageLimitMarker(
            sessionID: session.context.id,
            sequence: session.nextSequence,
            timestamp: now(),
            uptimeNanoseconds: uptimeNanoseconds(),
            startUptimeNanoseconds: session.context.startUptimeNanoseconds
        ) {
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

    func closeActiveSessionAfterFailure(
        sessionID: UUID? = nil,
        phase: BLETraceRecordingFailure.Phase
    ) async {
        let failedID = sessionID ?? activeSession?.context.id
        captureState.setRecording(false)
        writerTask?.cancel()
        writerTask = nil
        writerTaskID = nil
        pendingLines.removeAll()
        pendingLineIndex = 0
        pendingByteCount = 0
        try? activeSession?.fileHandle.close()
        activeSession = nil
        hasPreparedStorage = false
        reconcileCompletedSessionsFromDisk()
        if let failedID { await reportRecordingFailure(sessionID: failedID, phase: phase) }
        await publishSessions()
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

    func reconcileCompletedSessionsFromDisk() {
        completedSessions = (try? Self.loadStoredSessions(
            in: directory,
            fileManager: fileManager,
            codec: recordCodec
        )) ?? []
    }

}
