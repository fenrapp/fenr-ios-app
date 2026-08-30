import Foundation
import Testing

func temporaryBLETraceRoot() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
}

func traceRecords(at url: URL) throws -> [[String: Any]] {
    let data = try Data(contentsOf: url)
    return try data.split(separator: 0x0A).map {
        try #require(JSONSerialization.jsonObject(with: Data($0)) as? [String: Any])
    }
}

func jsonLine(_ object: [String: Any]) throws -> Data {
    var data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    data.append(0x0A)
    return data
}

func partialTrace(id: UUID) throws -> Data {
    var data = try jsonLine(BLETraceDataFixtures.header(id: id))
    data.append(try jsonLine(BLETraceDataFixtures.eventRecord(id: id)))
    return data
}

func completedTrace(
    header: [String: Any],
    footer: [String: Any]
) throws -> Data {
    var data = try jsonLine(header)
    data.append(try jsonLine(footer))
    return data
}

func writeCompletedTrace(
    to url: URL,
    id: UUID,
    startedAt: String = "1970-01-01T00:00:10.000Z",
    endedAt: String = "1970-01-01T00:01:10.000Z",
    paddingBytes: Int = 0
) throws {
    var data = try jsonLine(BLETraceDataFixtures.header(id: id, startedAt: startedAt))
    if paddingBytes > 0 {
        data.append(Data(repeating: 0x20, count: paddingBytes))
        data.append(0x0A)
    }
    data.append(try jsonLine(BLETraceDataFixtures.footer(id: id, endedAt: endedAt)))
    try data.write(to: url)
}

func traceJSONFiles(in directory: URL) throws -> [URL] {
    try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        .filter { $0.pathExtension == "jsonl" }
}

func assertStorageProtection(at url: URL) throws {
    let values = try url.resourceValues(forKeys: [.isExcludedFromBackupKey])
    #expect(values.isExcludedFromBackup == true)
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    if let protection = attributes[.protectionKey] as? FileProtectionType {
        #expect(protection == .completeUntilFirstUserAuthentication)
    }
}
