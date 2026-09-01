import AsyncSupport
import BLETraceData
import BLETraceDomain
import Foundation

struct BLETraceDataTestContext {
    let repository: FileBLETraceLogRepository
    let directory: URL
    let exportDirectory: URL
}

func makeBLETraceDataTestContext(
    maximumSessionCount: Int = 5,
    maximumTotalBytes: Int64 = 1_000_000,
    root: URL? = nil,
    now: @escaping @Sendable () -> Date = { Date(timeIntervalSince1970: 100) },
    fileManager: sending FileManager = .default,
    writerTaskStarter: any BLETraceWriterTaskStarter = LiveBLETraceWriterTaskStarter()
) throws -> BLETraceDataTestContext {
    let root = root ?? FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let directory = root.appendingPathComponent("logs", isDirectory: true)
    let exportDirectory = root.appendingPathComponent("exports", isDirectory: true)
    let repository = try FileBLETraceLogRepository.make(
        directory: directory,
        exportDirectory: exportDirectory,
        environment: BLETraceEnvironment(
            appVersion: "1.0",
            appBuild: "1",
            operatingSystem: "Test OS",
            deviceModel: "Test Device"
        ),
        configuration: BLETraceFileStoreConfiguration(
            maximumSessionCount: maximumSessionCount,
            maximumTotalBytes: maximumTotalBytes,
            terminalRecordReserveBytes: 256
        ),
        dependencies: BLETraceFileStoreDependencies(
            fileManager: fileManager,
            lineEncoder: BLETraceJSONLineEncoder(),
            sessionHub: AsyncEventHub(
                bufferingPolicy: .bufferingNewest(1),
                replaysLatestValue: true
            ),
            now: now,
            uptimeNanoseconds: { 200_000_000_000 },
            writerTaskStarter: writerTaskStarter
        )
    )
    return BLETraceDataTestContext(
        repository: repository,
        directory: directory,
        exportDirectory: exportDirectory
    )
}
