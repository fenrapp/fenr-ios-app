import Foundation

public struct PowerModeName: Codable, Equatable, Hashable, Sendable {
    public static let maximumLength = 10

    public let value: String

    public init(_ candidate: String) throws {
        let normalized = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            throw PowerModeNameValidationError.empty
        }
        guard normalized.count <= Self.maximumLength else {
            throw PowerModeNameValidationError.tooLong(maximumLength: Self.maximumLength)
        }
        value = normalized
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

    public var errorDescription: String? {
        switch self {
        case .empty:
            "Enter a map name."
        case .tooLong(let maximumLength):
            "Use no more than \(maximumLength) characters."
        }
    }
}
