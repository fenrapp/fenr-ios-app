import Foundation

public struct DebugEventViewData: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let time: String
    public let title: String
    public let detail: String

    public init(id: UUID, time: String, title: String, detail: String) {
        self.id = id
        self.time = time
        self.title = title
        self.detail = detail
    }
}
