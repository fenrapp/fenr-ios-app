import Foundation

public enum MaintenanceKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case breakInGearOil
    case brakeFluid
    case forkOil
    case forkService
    case motorGearInspection
    case chainLubrication
    case forkBleeding
    case tires
    case brakePads
    case brakeDiscs
    case chainDrive
    case coolant
    case shockAndLinkage
    case gearOil
    case bearings
    case electrical
    case generalInspection
    case custom

    public var id: String { rawValue }
}

public struct MaintenanceKindSelection: Equatable, Codable, Sendable {
    public let kind: MaintenanceKind
    public let customName: String?

    public init(kind: MaintenanceKind, customName: String? = nil) {
        self.kind = kind
        self.customName = customName?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var matchingKey: String {
        if kind == .custom {
            let normalized = (customName ?? "").folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
            return "custom:\(normalized)"
        }
        return kind.rawValue
    }

    public var isValid: Bool {
        kind != .custom || !(customName ?? "").isEmpty
    }
}
