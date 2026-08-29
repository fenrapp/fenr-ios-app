import EnvironmentDomain
import Foundation
import MapKit
import RideNavigationDomain

public struct AppleExternalMapLinkResolver: ExternalMapLinkResolving {
    private let redirectResolver: any MapLinkRedirectResolving
    private let placeSearch: any PlaceSearching

    public init(
        redirectResolver: any MapLinkRedirectResolving,
        placeSearch: any PlaceSearching
    ) {
        self.redirectResolver = redirectResolver
        self.placeSearch = placeSearch
    }

    public func destination(from url: URL) async throws -> NavigationPlace {
        guard url.absoluteString.count <= Constants.maximumURLLength else {
            throw ExternalMapLinkResolutionError.unsupportedURL
        }
        if MKDirections.Request.isDirectionsRequest(url) {
            let request = MKDirections.Request(contentsOf: url)
            guard let item = request.destination,
                  let coordinate = GeographicCoordinate(item.placemark.coordinate) else {
                throw ExternalMapLinkResolutionError.destinationUnavailable
            }
            return NavigationPlace(
                name: item.name ?? "Shared destination",
                detail: item.placemark.title ?? "Apple Maps",
                coordinate: coordinate
            )
        }

        let resolvedURL = try await resolvedMapURL(url)
        guard resolvedURL.scheme?.lowercased() == "https",
              let host = resolvedURL.host?.lowercased(),
              Constants.allowedHosts.contains(host) else {
            throw ExternalMapLinkResolutionError.unsupportedURL
        }
        guard let candidate = destinationCandidate(in: resolvedURL) else {
            throw ExternalMapLinkResolutionError.destinationUnavailable
        }
        if let coordinate = Self.coordinate(from: candidate) {
            return NavigationPlace(name: "Shared destination", detail: host, coordinate: coordinate)
        }
        guard let place = try await placeSearch.search(candidate, near: nil).first else {
            throw ExternalMapLinkResolutionError.destinationUnavailable
        }
        return place
    }

    private func resolvedMapURL(_ url: URL) async throws -> URL {
        guard url.scheme?.lowercased() == "https",
              let host = url.host?.lowercased(),
              Constants.allowedHosts.contains(host) else {
            throw ExternalMapLinkResolutionError.unsupportedURL
        }
        if Constants.shortLinkHosts.contains(host) {
            return try await redirectResolver.resolve(url)
        }
        return url
    }

    private func destinationCandidate(in url: URL) -> String? {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let query = (components?.queryItems ?? []).reduce(into: [String: String]()) { values, item in
            values[item.name.lowercased()] = item.value ?? ""
        }
        for key in Constants.destinationQueryKeys {
            if let value = query[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                return value
            }
        }

        let path = url.pathComponents
            .filter { $0 != "/" }
            .map { $0.removingPercentEncoding ?? $0 }
        if let placeIndex = path.firstIndex(of: "place"), path.indices.contains(placeIndex + 1) {
            return path[placeIndex + 1].replacingOccurrences(of: "+", with: " ")
        }
        if let directionsIndex = path.firstIndex(of: "dir") {
            let values = path.dropFirst(directionsIndex + 1).filter {
                !$0.isEmpty && !$0.hasPrefix("@") && !$0.hasPrefix("data=")
            }
            return values.last?.replacingOccurrences(of: "+", with: " ")
        }
        return nil
    }

    private static func coordinate(from value: String) -> GeographicCoordinate? {
        let components = value.split(separator: ",", maxSplits: 1).map(String.init)
        guard components.count == 2,
              let latitude = Double(components[0]),
              let longitude = Double(components[1]) else { return nil }
        return GeographicCoordinate(latitudeDegrees: latitude, longitudeDegrees: longitude)
    }

    private enum Constants {
        static let maximumURLLength = 2_048
        static let destinationQueryKeys = ["destination", "daddr", "address", "ll", "query", "q"]
        static let shortLinkHosts: Set<String> = ["maps.app.goo.gl", "goo.gl"]
        static let allowedHosts: Set<String> = [
            "maps.app.goo.gl",
            "goo.gl",
            "google.com",
            "www.google.com",
            "maps.google.com",
            "maps.apple.com"
        ]
    }
}

public struct URLSessionMapLinkRedirectResolver: MapLinkRedirectResolving {
    private let session: URLSession

    public init(session: URLSession) {
        self.session = session
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
    private let allowedHosts: Set<String>
    private let maximumRedirects: Int
    private let lock = NSLock()
    private var redirectCounts: [Int: Int] = [:]

    public init(allowedHosts: Set<String>, maximumRedirects: Int) {
        self.allowedHosts = allowedHosts
        self.maximumRedirects = maximumRedirects
    }

    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        let redirectCount = lock.withLock {
            let value = (redirectCounts[task.taskIdentifier] ?? .zero) + 1
            redirectCounts[task.taskIdentifier] = value
            return value
        }
        guard redirectCount <= maximumRedirects,
              request.url?.scheme?.lowercased() == "https",
              let host = request.url?.host?.lowercased(),
              allowedHosts.contains(host) else {
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

private extension GeographicCoordinate {
    init?(_ coordinate: CLLocationCoordinate2D) {
        self.init(latitudeDegrees: coordinate.latitude, longitudeDegrees: coordinate.longitude)
    }
}
