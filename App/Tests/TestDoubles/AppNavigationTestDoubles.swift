import Foundation
import RideNavigationDomain
import UIKit

actor AppNavigationIncomingMapLinkStore: IncomingMapLinkStoring {
    enum Failure: Error {
        case consumeFailed
    }

    private var links: [IncomingMapLink]
    private var remainingFailures: Int
    private var shouldBlock: Bool
    private var continuation: CheckedContinuation<Void, Never>?
    private var count = 0

    init(
        links: [IncomingMapLink] = [],
        failures: Int = 0,
        shouldBlock: Bool = false
    ) {
        self.links = links
        remainingFailures = failures
        self.shouldBlock = shouldBlock
    }

    func save(_ link: IncomingMapLink) {
        links.append(link)
    }

    func consume() async throws -> IncomingMapLink? {
        count += 1
        if shouldBlock {
            shouldBlock = false
            await withCheckedContinuation { continuation = $0 }
        }
        if remainingFailures > 0 {
            remainingFailures -= 1
            throw Failure.consumeFailed
        }
        return links.isEmpty ? nil : links.removeFirst()
    }

    func consumeCount() -> Int { count }
    func isBlocked() -> Bool { continuation != nil }

    func release() {
        let continuation = continuation
        self.continuation = nil
        continuation?.resume()
    }
}

@MainActor
final class AppNavigationOrientationSpy: InterfaceOrientationControlling {
    private(set) var requests: [UIInterfaceOrientationMask] = []

    func request(_ orientations: UIInterfaceOrientationMask) {
        requests.append(orientations)
    }
}
