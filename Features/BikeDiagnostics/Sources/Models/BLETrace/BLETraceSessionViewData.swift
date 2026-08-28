import Foundation

public struct BLETraceSessionViewData: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let date: String
    public let duration: String
    public let size: String
    public let status: String
    public let isActive: Bool
    public let canDelete: Bool

    public init(
        id: UUID,
        date: String,
        duration: String,
        size: String,
        status: String,
        isActive: Bool,
        canDelete: Bool
    ) {
        self.id = id
        self.date = date
        self.duration = duration
        self.size = size
        self.status = status
        self.isActive = isActive
        self.canDelete = canDelete
    }
}
