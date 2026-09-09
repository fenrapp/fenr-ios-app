import Foundation

public struct PowerModePresetViewData: Identifiable, Equatable, Sendable {
    static let maximumNameLength = 40
    public let id: UUID
    public let name: String
    public let isCompatible: Bool
}
