import Foundation

public struct BikeDebugEvent: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let date: Date
    public let title: String
    public let detail: String

    public init(id: UUID = UUID(), date: Date = Date(), title: String, detail: String) {
        self.id = id
        self.date = date
        self.title = title
        self.detail = detail
    }
}
