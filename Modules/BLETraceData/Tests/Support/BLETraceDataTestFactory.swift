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
    now: @escaping @Sendable () -> Date = { Date(timeIntervalSince1970: 100) }
) throws -> BLETraceDataTestContext {
    let root = root ?? FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let directory = root.appendingPathComponent("logs", isDirectory: true)
    let exportDirectory = root.appendingPathComponent("exports", isDirectory: true)
    let repository = try FileBLETraceLogRepository(
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
        fileManager: .default,
        lineEncoder: BLETraceJSONLineEncoder(),
        sessionHub: AsyncEventHub(replaysLatestValue: true),
        now: now,
        uptimeNanoseconds: { 200_000_000_000 }
    )
    return BLETraceDataTestContext(
        repository: repository,
        directory: directory,
        exportDirectory: exportDirectory
    )
}

func makeTraceContext(id: UUID = UUID(), startedAt: Date = Date(timeIntervalSince1970: 10))
    -> BLETraceSessionContext {
    BLETraceSessionContext(
        id: id,
        startedAt: startedAt,
        startUptimeNanoseconds: 10_000_000_000,
        reason: .connectionRequest
    )
}

func makeTraceEvent(index: Int, detail: String? = nil) -> BLETraceEvent {
    BLETraceEvent(
        timestamp: Date(timeIntervalSince1970: 10 + Double(index)),
        uptimeNanoseconds: 10_000_000_000 + UInt64(index) * 1_000_000,
        category: "gatt",
        operation: .valueUpdated,
        direction: .inbound,
        characteristicUUID: "00006004-5374-6172-4B20-467574757265",
        byteCount: 2,
        payloadHex: "AA BB",
        detail: detail
    )
}
