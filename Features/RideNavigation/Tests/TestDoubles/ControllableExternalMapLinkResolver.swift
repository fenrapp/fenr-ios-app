import Foundation
import RideNavigationDomain

actor ControllableExternalMapLinkResolver: ExternalMapLinkResolving {
    enum Failure: Error {
        case unavailable
    }

    private var requests: [URL: CheckedContinuation<NavigationPlace, any Error>] = [:]

    func destination(from url: URL) async throws -> NavigationPlace {
        try await withCheckedThrowingContinuation { continuation in
            requests[url] = continuation
        }
    }

    func hasRequest(for url: URL) -> Bool {
        requests[url] != nil
    }

    func succeed(url: URL, destination: NavigationPlace) {
        requests.removeValue(forKey: url)?.resume(returning: destination)
    }

    func fail(url: URL) {
        requests.removeValue(forKey: url)?.resume(throwing: Failure.unavailable)
    }
}
