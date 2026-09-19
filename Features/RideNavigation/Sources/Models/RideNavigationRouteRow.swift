import Foundation

public struct RideNavigationRouteRow: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let offlineStatus: String?
    public let detail: String

    public init(id: UUID, title: String, detail: String, offlineStatus: String? = nil) {
        self.offlineStatus = offlineStatus
        self.id = id
        self.title = title
        self.detail = detail
    }
}
