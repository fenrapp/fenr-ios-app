import Foundation
import RideNavigationDomain

public protocol StoredRideRouteCoding: Sendable {
    func encode(_ route: RideRoute) throws -> Data
    func decode(_ data: Data) throws -> RideRoute
}
