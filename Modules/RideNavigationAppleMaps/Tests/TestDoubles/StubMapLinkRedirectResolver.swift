import Foundation
import RideNavigationDomain

struct StubMapLinkRedirectResolver: MapLinkRedirectResolving {
    let result: URL

    func resolve(_: URL) async throws -> URL {
        result
    }
}
