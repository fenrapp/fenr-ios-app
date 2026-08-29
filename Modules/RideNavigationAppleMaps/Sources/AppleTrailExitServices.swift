import EnvironmentDomain
import Foundation
import MapKit
import RideNavigationDomain

public struct AppleTrailExitCandidateSearch: TrailExitCandidateSearching {
    public init() {}

    public func candidates(
        near origin: GeographicCoordinate,
        radiusMeters: Double
    ) async throws -> [NavigationPlace] {
        let region = MKCoordinateRegion(
            center: origin.clCoordinate,
            latitudinalMeters: radiusMeters * 2,
            longitudinalMeters: radiusMeters * 2
        )
        async let pointsOfInterest = searchPointsOfInterest(in: region)
        async let townCenters = searchTownCenters(in: region)
        let results = try await (pointsOfInterest, townCenters)
        return deduplicated(results.0 + results.1)
    }

    private func searchPointsOfInterest(in region: MKCoordinateRegion) async throws -> [NavigationPlace] {
        let request = MKLocalPointsOfInterestRequest(coordinateRegion: region)
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [
            .parking,
            .gasStation,
            .police,
            .fireStation,
            .hospital,
            .hotel,
            .campground
        ])
        return try await MKLocalSearch(request: request).start().mapItems.compactMap(Self.place)
    }

    private func searchTownCenters(in region: MKCoordinateRegion) async throws -> [NavigationPlace] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "town center"
        request.region = region
        if #available(iOS 18.0, *) {
            request.regionPriority = .required
        }
        request.resultTypes = .address
        return try await MKLocalSearch(request: request).start().mapItems.compactMap(Self.place)
    }

    private func deduplicated(_ places: [NavigationPlace]) -> [NavigationPlace] {
        var seen: Set<String> = []
        return places.filter { place in
            let key = String(format: "%.5f,%.5f", place.coordinate.latitudeDegrees, place.coordinate.longitudeDegrees)
            return seen.insert(key).inserted
        }
    }

    private static func place(_ item: MKMapItem) -> NavigationPlace? {
        guard let coordinate = GeographicCoordinate(item.placemark.coordinate) else { return nil }
        return NavigationPlace(
            name: item.name ?? "Road-accessible place",
            detail: item.placemark.title ?? "Apple Maps",
            coordinate: coordinate
        )
    }
}

public struct AppleTrailExitFinder: TrailExitFinding {
    private let candidateSearch: any TrailExitCandidateSearching
    private let roadRouteCalculator: any RoadRouteCalculating

    public init(
        candidateSearch: any TrailExitCandidateSearching,
        roadRouteCalculator: any RoadRouteCalculating
    ) {
        self.candidateSearch = candidateSearch
        self.roadRouteCalculator = roadRouteCalculator
    }

    public func findExit(
        from origin: GeographicCoordinate,
        preferences: RoadRoutePreferences
    ) async throws -> TrailExitRoute {
        var candidates: [NavigationPlace] = []
        var seen: Set<String> = []
        for radius in Constants.searchRadiiMeters where candidates.count < Constants.maximumRouteAttempts {
            try Task.checkCancellation()
            let found = try await candidateSearch.candidates(near: origin, radiusMeters: radius)
                .sorted { distance(from: origin, to: $0) < distance(from: origin, to: $1) }
            for candidate in found where candidates.count < Constants.maximumRouteAttempts {
                let key = String(
                    format: "%.5f,%.5f",
                    candidate.coordinate.latitudeDegrees,
                    candidate.coordinate.longitudeDegrees
                )
                if seen.insert(key).inserted {
                    candidates.append(candidate)
                }
            }
        }

        var best: TrailExitRoute?
        for candidate in candidates {
            try Task.checkCancellation()
            do {
                let route = try await roadRouteCalculator.route(
                    from: origin,
                    to: candidate,
                    preferences: preferences
                )
                let option = TrailExitRoute(destination: candidate, route: route)
                if best.map({ Self.precedes(option, $0) }) ?? true {
                    best = option
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                continue
            }
        }
        guard let best else { throw TrailExitFindingError.exitUnavailable }
        return best
    }

    private func distance(from origin: GeographicCoordinate, to place: NavigationPlace) -> Double {
        RideRouteGeometry.distanceMeters(from: origin, to: place.coordinate)
    }

    private static func precedes(_ lhs: TrailExitRoute, _ rhs: TrailExitRoute) -> Bool {
        if lhs.route.distanceMeters == rhs.route.distanceMeters {
            return lhs.route.expectedTravelTime < rhs.route.expectedTravelTime
        }
        return lhs.route.distanceMeters < rhs.route.distanceMeters
    }

    private enum Constants {
        static let searchRadiiMeters = [5_000.0, 15_000.0, 40_000.0]
        static let maximumRouteAttempts = 8
    }
}

private extension GeographicCoordinate {
    init?(_ coordinate: CLLocationCoordinate2D) {
        self.init(latitudeDegrees: coordinate.latitude, longitudeDegrees: coordinate.longitude)
    }

    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitudeDegrees, longitude: longitudeDegrees)
    }
}
