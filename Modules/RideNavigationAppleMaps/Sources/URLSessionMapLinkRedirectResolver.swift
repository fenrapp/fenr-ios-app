import Foundation
import RideNavigationDomain

public final class URLSessionMapLinkRedirectResolver: MapLinkRedirectResolving, Sendable {
    private let session: URLSession
    private let invalidatesSessionOnDeinit: Bool

    public init(session: URLSession) {
        self.session = session
        invalidatesSessionOnDeinit = false
    }

    public init(ownedSession: URLSession) {
        session = ownedSession
        invalidatesSessionOnDeinit = true
    }

    deinit {
        guard invalidatesSessionOnDeinit else { return }
        session.invalidateAndCancel()
    }

    public func resolve(_ url: URL) async throws -> URL {
        let (_, response) = try await session.data(from: url)
        guard let resolvedURL = response.url else {
            throw ExternalMapLinkResolutionError.destinationUnavailable
        }
        return resolvedURL
    }
}

public final class AllowedMapLinkRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let policy: AppleMapLinkSecurityPolicy
    private let lock = NSLock()
    private var redirectCounts: [Int: Int] = [:]

    public init(policy: AppleMapLinkSecurityPolicy = .standard) {
        self.policy = policy
    }

    public convenience init(allowedHosts: Set<String>, maximumRedirects: Int) {
        self.init(
            policy: AppleMapLinkSecurityPolicy(
                allowedHosts: allowedHosts,
                shortLinkHosts: [],
                maximumURLLength: AppleMapLinkSecurityPolicy.standard.maximumURLLength,
                maximumRedirects: maximumRedirects
            )
        )
    }

    public func urlSession(
        _: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection _: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        let redirectCount = lock.withLock {
            let value = (redirectCounts[task.taskIdentifier] ?? .zero) + 1
            redirectCounts[task.taskIdentifier] = value
            return value
        }
        guard redirectCount <= policy.maximumRedirects,
              let url = request.url,
              policy.allows(url) else {
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }

    public func urlSession(
        _: URLSession,
        task: URLSessionTask,
        didCompleteWithError _: (any Error)?
    ) {
        lock.withLock {
            redirectCounts[task.taskIdentifier] = nil
        }
    }
}
