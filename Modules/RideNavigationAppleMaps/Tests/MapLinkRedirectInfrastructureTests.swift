import Foundation
@testable import RideNavigationAppleMaps
import Testing
import TestSupport

struct MapLinkRedirectInfrastructureTests {
    @Test("allows a configured HTTPS redirect within the limit")
    func allowsConfiguredHTTPSRedirectWithinLimit() throws {
        let fixture = try RedirectFixture()
        let request = URLRequest(url: try #require(URL(string: "https://maps.example.com/destination")))

        let redirected = fixture.redirect(request, task: fixture.session.dataTask(with: fixture.sourceURL))

        #expect(redirected?.url == request.url)
    }

    @Test("rejects insecure, unlisted, and excess redirects")
    func rejectsInsecureUnlistedAndExcessRedirects() throws {
        let fixture = try RedirectFixture()
        let insecure = URLRequest(url: try #require(URL(string: "http://maps.example.com/destination")))
        let unlisted = URLRequest(url: try #require(URL(string: "https://example.com/destination")))
        let allowed = URLRequest(url: try #require(URL(string: "https://maps.example.com/destination")))

        #expect(fixture.redirect(insecure, task: fixture.session.dataTask(with: fixture.sourceURL)) == nil)
        #expect(fixture.redirect(unlisted, task: fixture.session.dataTask(with: fixture.sourceURL)) == nil)
        let countedTask = fixture.session.dataTask(with: fixture.sourceURL)
        #expect(fixture.redirect(allowed, task: countedTask) != nil)
        #expect(fixture.redirect(allowed, task: countedTask) == nil)
    }

    @Test("completion clears the redirect count for a task")
    func completionClearsRedirectCountForTask() throws {
        let fixture = try RedirectFixture()
        let task = fixture.session.dataTask(with: fixture.sourceURL)
        let request = URLRequest(url: try #require(URL(string: "https://maps.example.com/destination")))

        #expect(fixture.redirect(request, task: task) != nil)
        fixture.delegate.urlSession(fixture.session, task: task, didCompleteWithError: nil)

        #expect(fixture.redirect(request, task: task) != nil)
    }

    @Test("an explicitly owned resolver invalidates its session on deinit")
    func ownedResolverInvalidatesSessionOnDeinit() async {
        let delegate = RecordingURLSessionInvalidationDelegate()
        let session = URLSession(
            configuration: .ephemeral,
            delegate: delegate,
            delegateQueue: nil
        )
        var resolver: URLSessionMapLinkRedirectResolver? = URLSessionMapLinkRedirectResolver(
            ownedSession: session
        )

        #expect(resolver != nil)
        resolver = nil

        #expect(await waitUntil { delegate.invalidationCount() == 1 })
    }

    private final class RedirectFixture {
        let policy: AppleMapLinkSecurityPolicy
        let delegate: AllowedMapLinkRedirectDelegate
        let session: URLSession
        let sourceURL: URL
        let response: HTTPURLResponse

        init() throws {
            policy = AppleMapLinkSecurityPolicy(
                allowedHosts: ["maps.example.com"],
                shortLinkHosts: [],
                maximumURLLength: 256,
                maximumRedirects: 1
            )
            delegate = AllowedMapLinkRedirectDelegate(policy: policy)
            session = URLSession(configuration: .ephemeral)
            sourceURL = try #require(URL(string: "https://maps.example.com/source"))
            response = try #require(
                HTTPURLResponse(
                    url: sourceURL,
                    statusCode: 302,
                    httpVersion: nil,
                    headerFields: nil
                )
            )
        }

        deinit {
            session.invalidateAndCancel()
        }

        func redirect(_ request: URLRequest, task: URLSessionTask) -> URLRequest? {
            var redirectedRequest: URLRequest?
            delegate.urlSession(
                session,
                task: task,
                willPerformHTTPRedirection: response,
                newRequest: request
            ) { redirectedRequest = $0 }
            return redirectedRequest
        }
    }
}
