import Foundation

enum StarkUUIDFactory {
    private static let proprietarySuffix = "-5374-6172-4b20-467574757265"

    static func proprietary(_ assignedNumber: String) -> UUID {
        make(assignedNumber + proprietarySuffix)
    }

    static func standard(_ value: String) -> UUID {
        make(value)
    }

    private static func make(_ value: String) -> UUID {
        guard let uuid = UUID(uuidString: value) else {
            preconditionFailure("Invalid protocol UUID: \(value)")
        }
        return uuid
    }
}
