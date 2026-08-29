import EnvironmentDomain
import Foundation

public struct NavigationPlace: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let detail: String
    public let coordinate: GeographicCoordinate

    public init(
        id: UUID = UUID(),
        name: String,
        detail: String,
        coordinate: GeographicCoordinate
    ) {
        self.id = id
        self.name = name
        self.detail = detail
        self.coordinate = coordinate
    }
}
