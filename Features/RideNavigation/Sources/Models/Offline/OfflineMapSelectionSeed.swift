import Foundation

public struct OfflineMapSelectionSeed: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let routeID: UUID?
    public let segments: [[NavigationMapCoordinate]]
    public let center: NavigationMapCoordinate?

    public init(
        id: UUID = UUID(), name: String, routeID: UUID? = nil,
        segments: [[NavigationMapCoordinate]] = [], center: NavigationMapCoordinate? = nil
    ) {
        self.id = id
        self.name = name
        self.routeID = routeID
        self.segments = segments
        self.center = center
    }
}
