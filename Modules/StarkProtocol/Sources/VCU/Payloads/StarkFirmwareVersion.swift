import Foundation

public struct StarkFirmwareVersion: Comparable, Equatable, Sendable {
    public static let minimumChargePowerControl = StarkFirmwareVersion(major: 1, minor: 9, patch: 1)
    public static let minimumTractionControl = StarkFirmwareVersion(major: 1, minor: 10, patch: 1)

    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public init?(_ string: String) {
        let parts = string.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 3,
              let major = Int(parts[0]),
              let minor = Int(parts[1]),
              let patch = Int(parts[2].prefix(while: { $0.isNumber }))
        else {
            return nil
        }
        self.init(major: major, minor: minor, patch: patch)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }

    public var isChargePowerControlCompatible: Bool {
        self >= Self.minimumChargePowerControl
    }

    public var isTractionControlCompatible: Bool {
        self >= Self.minimumTractionControl
    }

    public var description: String {
        "\(major).\(minor).\(patch)"
    }
}

public enum StarkFirmwareVersionParser {
    public static func parseVCUPic(from data: Data) -> StarkFirmwareVersion? {
        if let asciiVersion = parseASCII(from: data) {
            return asciiVersion
        }
        if let vcuPICVersion = parseVersionBlocks(from: data).first {
            return vcuPICVersion
        }
        return parseBinaryTriplet(from: data)
    }

    public static func parseVersionBlockDescriptions(from data: Data) -> [String] {
        parseVersionBlocks(from: data).map(\.description)
    }

    private static func parseASCII(from data: Data) -> StarkFirmwareVersion? {
        let asciiBytes = data.filter { byte in
            byte == 0x2E || byte == 0x2D || byte == 0x5F || (0x20 ... 0x7E).contains(byte)
        }
        let ascii = String(bytes: asciiBytes, encoding: .utf8) ?? ""
        guard let match = ascii.range(
            of: #"(\d+)\.(\d+)\.(\d+)"#,
            options: .regularExpression
        ) else {
            return nil
        }
        return StarkFirmwareVersion(String(ascii[match]))
    }

    private static func parseBinaryTriplet(from data: Data) -> StarkFirmwareVersion? {
        guard data.count >= 3 else { return nil }
        let bytes = Array(data)
        for index in 0 ... (bytes.count - 3) {
            let major = Int(bytes[index])
            let minor = Int(bytes[index + 1])
            let patch = Int(bytes[index + 2])
            guard (1 ... 9).contains(major),
                  (0 ... 99).contains(minor),
                  (0 ... 99).contains(patch)
            else {
                continue
            }
            return StarkFirmwareVersion(major: major, minor: minor, patch: patch)
        }
        return nil
    }

    private static func parseVersionBlocks(from data: Data) -> [StarkFirmwareVersion] {
        guard data.count >= 4 else { return [] }
        let bytes = Array(data)
        return stride(from: 0, through: bytes.count - 4, by: 4).compactMap { index in
            let patch = Int(bytes[index])
            let minor = Int(bytes[index + 1])
            let major = Int(bytes[index + 2])
            let reserved = bytes[index + 3]
            guard reserved == 0x00,
                  (1 ... 9).contains(major),
                  (0 ... 99).contains(minor),
                  (0 ... 99).contains(patch)
            else {
                return nil
            }
            return StarkFirmwareVersion(major: major, minor: minor, patch: patch)
        }
    }
}
