import Foundation

public struct RideNavigationSearchResult: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let detail: String

    public init(id: UUID, title: String, detail: String) {
        self.id = id
        self.title = title
        self.detail = detail
    }
}
