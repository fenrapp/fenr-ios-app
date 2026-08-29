import Foundation
@testable import RideNavigationAppleMaps
import RideNavigationDomain
import Testing

struct AppleExternalMapLinkResolverTests {
    @Test("imports only the destination from a Google Maps route")
    func resolvesGoogleDestination() async throws {
        let url = try #require(
            URL(string: "https://www.google.com/maps/dir/?api=1&origin=Madrid&destination=41.1,2.1")
        )
        let resolver = AppleExternalMapLinkResolver(
            redirectResolver: StubMapLinkRedirectResolver(result: url),
            placeSearch: StubPlaceSearch(result: [])
        )

        let destination = try await resolver.destination(from: url)

        #expect(destination.coordinate.latitudeDegrees == 41.1)
        #expect(destination.coordinate.longitudeDegrees == 2.1)
    }

    @Test("resolves an allowed Google short link before parsing")
    func resolvesShortLink() async throws {
        let shortURL = try #require(URL(string: "https://maps.app.goo.gl/example"))
        let resolvedURL = try #require(URL(string: "https://maps.apple.com/?daddr=40.4,-3.7"))
        let resolver = AppleExternalMapLinkResolver(
            redirectResolver: StubMapLinkRedirectResolver(result: resolvedURL),
            placeSearch: StubPlaceSearch(result: [])
        )

        let destination = try await resolver.destination(from: shortURL)

        #expect(destination.coordinate.latitudeDegrees == 40.4)
        #expect(destination.coordinate.longitudeDegrees == -3.7)
    }

    @Test("rejects insecure map links")
    func rejectsInsecureMapLink() async throws {
        let url = try #require(URL(string: "http://maps.apple.com/?daddr=40.4,-3.7"))
        let resolver = AppleExternalMapLinkResolver(
            redirectResolver: StubMapLinkRedirectResolver(result: url),
            placeSearch: StubPlaceSearch(result: [])
        )

        await #expect(throws: ExternalMapLinkResolutionError.unsupportedURL) {
            _ = try await resolver.destination(from: url)
        }
    }

    @Test("rejects a short link that resolves outside the allowlist")
    func rejectsRedirectOutsideAllowlist() async throws {
        let shortURL = try #require(URL(string: "https://maps.app.goo.gl/example"))
        let resolvedURL = try #require(URL(string: "https://example.com/?daddr=40.4,-3.7"))
        let resolver = AppleExternalMapLinkResolver(
            redirectResolver: StubMapLinkRedirectResolver(result: resolvedURL),
            placeSearch: StubPlaceSearch(result: [])
        )

        await #expect(throws: ExternalMapLinkResolutionError.unsupportedURL) {
            _ = try await resolver.destination(from: shortURL)
        }
    }
}
