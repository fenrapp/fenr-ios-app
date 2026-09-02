import EnvironmentDomain
import Foundation
import MapKit
import RideNavigationDomain

public struct AppleExternalMapLinkResolver: ExternalMapLinkResolving {
    private let redirectResolver: any MapLinkRedirectResolving
    private let placeSearch: any PlaceSearching
    private let securityPolicy: AppleMapLinkSecurityPolicy

    public init(
        redirectResolver: any MapLinkRedirectResolving,
        placeSearch: any PlaceSearching,
        securityPolicy: AppleMapLinkSecurityPolicy = .standard
    ) {
        self.redirectResolver = redirectResolver
        self.placeSearch = placeSearch
        self.securityPolicy = securityPolicy
    }

    public func destination(from url: URL) async throws -> NavigationPlace {
        guard securityPolicy.allows(url) else {
            throw ExternalMapLinkResolutionError.unsupportedURL
        }
        if MKDirections.Request.isDirectionsRequest(url) {
            let request = MKDirections.Request(contentsOf: url)
            guard let item = request.destination,
                  let coordinate = GeographicCoordinate(item.placemark.coordinate) else {
                throw ExternalMapLinkResolutionError.destinationUnavailable
            }
            return NavigationPlace(
                name: item.name ?? String(localized: .rideNavigationAppleMapsSharedDestination),
                detail: item.placemark.title ?? String(localized: .rideNavigationAppleMapsProvider),
                coordinate: coordinate
            )
        }

        let resolvedURL = try await resolvedMapURL(url)
        guard securityPolicy.allows(resolvedURL),
              let host = resolvedURL.host?.lowercased() else {
            throw ExternalMapLinkResolutionError.unsupportedURL
        }
        guard let candidate = destinationCandidate(in: resolvedURL) else {
            throw ExternalMapLinkResolutionError.destinationUnavailable
        }
        if let coordinate = Self.coordinate(from: candidate) {
            return NavigationPlace(
                name: String(localized: .rideNavigationAppleMapsSharedDestination),
                detail: host,
                coordinate: coordinate
            )
        }
        guard let place = try await placeSearch.search(candidate, near: nil).first else {
            throw ExternalMapLinkResolutionError.destinationUnavailable
        }
        return place
    }

    private func resolvedMapURL(_ url: URL) async throws -> URL {
        if securityPolicy.isShortLink(url) {
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
        static let destinationQueryKeys = ["destination", "daddr", "address", "ll", "query", "q"]
    }
}
