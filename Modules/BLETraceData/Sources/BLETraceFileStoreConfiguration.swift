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
