import Foundation
import RideNavigationData
import RideNavigationDomain

final class CountingStoredRideRouteCodec: StoredRideRouteCoding, @unchecked Sendable {
    private let base: StoredRideRouteCodec
    private let lock = NSLock()
    private var count = 0

    init(base: StoredRideRouteCodec) { self.base = base }

    var decodeCount: Int { lock.withLock { count } }

    func encode(_ route: RideRoute) throws -> Data { try base.encode(route) }

    func decode(_ data: Data) throws -> RideRoute {
        lock.withLock { count += 1 }
        return try base.decode(data)
    }
}
