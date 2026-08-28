import Foundation

public struct PowerModeName: Codable, Equatable, Hashable, Sendable {
    public static let maximumLength = 10

    public let value: String

    public init(_ candidate: String) throws {
        guard !candidate.isEmpty else {
            throw PowerModeNameValidationError.empty
        }
        guard candidate.unicodeScalars.allSatisfy(Self.isAllowed) else {
            throw PowerModeNameValidationError.invalidCharacters
        }
        guard candidate.count <= Self.maximumLength else {
            throw PowerModeNameValidationError.tooLong(maximumLength: Self.maximumLength)
        }
        value = candidate
    }

    public func matchesIgnoringCase(_ other: Self) -> Bool {
        value.caseInsensitiveCompare(other.value) == .orderedSame
    }

    private enum CodingKeys: String, CodingKey {
        case value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(container.decode(String.self, forKey: .value))
    }

    private static func isAllowed(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 48 ... 57, 65 ... 90, 97 ... 122:
            true
        default:
            false
        }
    }
}

public enum PowerModeNameAssignmentError: Error, Equatable, LocalizedError, Sendable {
    case invalidMapIndex
    case duplicate

    public var errorDescription: String? {
        switch self {
        case .invalidMapIndex:
            "Select a valid power map."
        case .duplicate:
            "Use a unique name for each map."
        }
    }
}

public enum PowerModeNameValidationError: Error, Equatable, LocalizedError, Sendable {
    case empty
    case tooLong(maximumLength: Int)
    case invalidCharacters

    public var errorDescription: String? {
        switch self {
        case .empty:
            "Enter a map name."
        case .tooLong(let maximumLength):
            "Use no more than \(maximumLength) characters."
        case .invalidCharacters:
            "Use one word containing only letters and numbers."
        }
    }
}
