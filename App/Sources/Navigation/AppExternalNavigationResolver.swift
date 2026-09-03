import Foundation

enum AppExternalNavigationRequest: Equatable {
    case rideNavigation(resourceURL: URL?)
}

struct AppExternalNavigationResolver {
    func resolve(_ url: URL) -> AppExternalNavigationRequest? {
        if url.scheme?.lowercased() == "fenr-app",
           url.host?.lowercased() == "ride-navigation" {
            return .rideNavigation(resourceURL: nil)
        }

        let scheme = url.scheme?.lowercased()
        let pathExtension = url.pathExtension.lowercased()
        guard pathExtension == "gpx"
                || pathExtension == "directionsrequest"
                || scheme == "https" else {
            return nil
        }
        return .rideNavigation(resourceURL: url)
    }
}
