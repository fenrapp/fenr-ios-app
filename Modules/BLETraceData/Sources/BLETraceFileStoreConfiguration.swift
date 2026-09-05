import AsyncSupport
import BLETraceDomain
import Foundation

public struct BLETraceFileStoreConfiguration: Sendable {
    public let maximumSessionCount: Int
    public let maximumTotalBytes: Int64
    public let terminalRecordReserveBytes: Int64

    public init(
        maximumSessionCount: Int = 5,
        maximumTotalBytes: Int64 = 1_073_741_824,
        terminalRecordReserveBytes: Int64 = 4_096
    ) {
        self.maximumSessionCount = maximumSessionCount
        self.maximumTotalBytes = maximumTotalBytes
        self.terminalRecordReserveBytes = terminalRecordReserveBytes
    }
}

public struct BLETraceJSONLineEncoder: Sendable {
    public init() {}

    public func encode<Value: Encodable>(_ value: Value) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        var data = try encoder.encode(value)
        data.append(0x0A)
        return data
    }
}

public struct BLETraceFileStoreDependencies {
    let captureState: BLETraceCaptureState
    let fileManager: FileManager
    let lineEncoder: BLETraceJSONLineEncoder
    let failureHub: AsyncEventHub<BLETraceRecordingFailure?>
    let sessionHub: AsyncEventHub<[BLETraceSessionSummary]>
    let now: @Sendable () -> Date
    let uptimeNanoseconds: @Sendable () -> UInt64
    let writerTaskStarter: any BLETraceWriterTaskStarter

    public init(
        captureState: BLETraceCaptureState,
        fileManager: sending FileManager,
        lineEncoder: BLETraceJSONLineEncoder,
        sessionHub: AsyncEventHub<[BLETraceSessionSummary]>,
        failureHub: AsyncEventHub<BLETraceRecordingFailure?>,
        now: @escaping @Sendable () -> Date,
        uptimeNanoseconds: @escaping @Sendable () -> UInt64,
        writerTaskStarter: any BLETraceWriterTaskStarter
    ) {
        self.captureState = captureState
        self.fileManager = fileManager
        self.lineEncoder = lineEncoder
        self.sessionHub = sessionHub
        self.failureHub = failureHub
        self.now = now
        self.uptimeNanoseconds = uptimeNanoseconds
        self.writerTaskStarter = writerTaskStarter
    }
}
