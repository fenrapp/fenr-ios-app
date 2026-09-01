@preconcurrency import AVFoundation
import EnvironmentDomain
import MapKit
import RideNavigation
import RideNavigationDomain
import UIKit

public struct ApplePlaceSearchService: PlaceSearching {
    public init() {}

    public func search(_ query: String, near coordinate: GeographicCoordinate?) async throws -> [NavigationPlace] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let coordinate {
            request.region = MKCoordinateRegion(
                center: coordinate.clCoordinate,
                latitudinalMeters: Constants.searchSpanMeters,
                longitudinalMeters: Constants.searchSpanMeters
            )
        }
        let response = try await MKLocalSearch(request: request).start()
        return response.mapItems.compactMap { item in
            guard let coordinate = GeographicCoordinate(item.placemark.coordinate) else { return nil }
            let detail = [item.placemark.locality, item.placemark.administrativeArea]
                .compactMap { $0 }
                .joined(separator: ", ")
            return NavigationPlace(name: item.name ?? "Destination", detail: detail, coordinate: coordinate)
        }
    }

    private enum Constants { static let searchSpanMeters: CLLocationDistance = 100_000 }
}

public struct AppleRoadRouteCalculator: RoadRouteCalculating {
    public init() {}

    public func routes(
        from origin: GeographicCoordinate,
        to destination: NavigationPlace,
        preferences: RoadRoutePreferences
    ) async throws -> [RoadNavigationRoute] {
        let request = AppleRoadRouteRequestFactory.make(
            origin: origin,
            destination: destination,
            preferences: preferences
        )
        let response = try await MKDirections(request: request).calculate()
        guard !response.routes.isEmpty else {
            throw RoadRouteCalculationError.routeUnavailable
        }
        return response.routes.map { route in
            RoadNavigationRoute(
                name: route.name.isEmpty ? destination.name : route.name,
                points: route.polyline.coordinates.compactMap(GeographicCoordinate.init),
                distanceMeters: route.distance,
                expectedTravelTime: route.expectedTravelTime,
                steps: route.steps.map {
                    RoadNavigationStep(
                        instruction: $0.instructions,
                        distanceMeters: $0.distance,
                        points: $0.polyline.coordinates.compactMap(GeographicCoordinate.init)
                    )
                },
                containsTolls: route.hasTolls,
                containsHighways: route.hasHighways
            )
        }
    }
}

enum AppleRoadRouteRequestFactory {
    static func make(
        origin: GeographicCoordinate,
        destination: NavigationPlace,
        preferences: RoadRoutePreferences
    ) -> MKDirections.Request {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin.clCoordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination.coordinate.clCoordinate))
        request.transportType = .automobile
        request.requestsAlternateRoutes = true
        request.tollPreference = preferences.avoidsTolls ? .avoid : .any
        request.highwayPreference = preferences.avoidsHighways ? .avoid : .any
        return request
    }
}

@MainActor
public final class AppleNavigationGuidanceClient: NavigationGuidanceClient {
    private let synthesizer: AVSpeechSynthesizer
    private let notificationGenerator: UINotificationFeedbackGenerator

    public init(
        synthesizer: AVSpeechSynthesizer,
        notificationGenerator: UINotificationFeedbackGenerator
    ) {
        self.synthesizer = synthesizer
        self.notificationGenerator = notificationGenerator
    }

    public func announce(_ text: String) async {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.autoupdatingCurrent.identifier)
        synthesizer.speak(utterance)
    }

    public func notifyWarning() async {
        notificationGenerator.notificationOccurred(.warning)
    }

    public func notifySuccess() async {
        notificationGenerator.notificationOccurred(.success)
    }
}
