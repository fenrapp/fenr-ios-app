import Foundation

public struct RideRouteSummary: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let createdAt: Date
    public let updatedAt: Date
    public let distanceMeters: Double

    public init(_ route: RideRoute) {
        id = route.id
        name = route.name
        createdAt = route.createdAt
        updatedAt = route.updatedAt
        distanceMeters = route.distanceMeters
    }
}
