import Foundation

public struct AppleMapLinkSecurityPolicy: Equatable, Sendable {
    public let allowedHosts: Set<String>
    public let shortLinkHosts: Set<String>
    public let maximumURLLength: Int
    public let maximumRedirects: Int

    public init(
        allowedHosts: Set<String>,
        shortLinkHosts: Set<String>,
        maximumURLLength: Int,
        maximumRedirects: Int
    ) {
        self.allowedHosts = allowedHosts
        self.shortLinkHosts = shortLinkHosts
        self.maximumURLLength = maximumURLLength
        self.maximumRedirects = maximumRedirects
    }

    public static let standard = AppleMapLinkSecurityPolicy(
        allowedHosts: [
            "maps.app.goo.gl",
            "goo.gl",
            "google.com",
            "www.google.com",
            "maps.google.com",
            "maps.apple.com"
        ],
        shortLinkHosts: ["maps.app.goo.gl", "goo.gl"],
        maximumURLLength: 2_048,
        maximumRedirects: 5
    )

    func allows(_ url: URL) -> Bool {
        guard url.absoluteString.count <= maximumURLLength,
              url.scheme?.lowercased() == "https",
              let host = url.host?.lowercased() else { return false }
        return allowedHosts.contains(host)
    }

    func isShortLink(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return shortLinkHosts.contains(host)
    }
}
