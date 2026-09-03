import Foundation

public struct BLETraceSessionViewData: Equatable, Identifiable, Sendable {
    public enum Status: Equatable, Sendable {
        case recording
        case complete
        case incomplete
        case truncated
    }

    public let id: UUID
    public let date: String
    public let duration: String
    public let size: String
    public let eventCount: String
    public let status: String
    public let statusKind: Status
    public let isActive: Bool
    public let canDelete: Bool

    public init(
        id: UUID,
        date: String,
        duration: String,
        size: String,
        eventCount: String,
        status: String,
        statusKind: Status,
        isActive: Bool,
        canDelete: Bool
    ) {
        self.id = id
        self.date = date
        self.duration = duration
        self.size = size
        self.eventCount = eventCount
        self.status = status
        self.statusKind = statusKind
        self.isActive = isActive
        self.canDelete = canDelete
    }
}
