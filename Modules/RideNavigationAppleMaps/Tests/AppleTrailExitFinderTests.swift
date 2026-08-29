import EnvironmentDomain
@testable import RideNavigationAppleMaps
import RideNavigationDomain
import Testing

struct AppleTrailExitFinderTests {
    @Test("ranks real road routes, preserves preferences, and caps route attempts")
    func ranksAccessibleExits() async throws {
        let origin = coordinate(latitude: 41, longitude: 2)
        let candidates = (0 ..< 9).map { index in
            NavigationPlace(
                name: "Candidate \(index)",
                detail: "Apple Maps",
                coordinate: coordinate(latitude: 41 + Double(index + 1) * 0.001, longitude: 2)
            )
        }
        let search = RecordingTrailExitCandidateSearch(results: candidates)
        let routeCalculator = RecordingTrailExitRouteCalculator(
            values: Dictionary(uniqueKeysWithValues: (0 ..< 8).map { index in
                let distance = index == 6 ? 750.0 : 2_000.0 + Double(index)
                return ("Candidate \(index)", .init(distanceMeters: distance, travelTime: 300))
            })
        )
        let finder = AppleTrailExitFinder(
            candidateSearch: search,
            roadRouteCalculator: routeCalculator
        )
        let preferences = RoadRoutePreferences(avoidsTolls: true, avoidsHighways: true)

        let exit = try await finder.findExit(from: origin, preferences: preferences)

        #expect(exit.destination.name == "Candidate 6")
        #expect(await routeCalculator.requestedDestinations().count == 8)
        #expect(await routeCalculator.requestedPreferences().allSatisfy { $0 == preferences })
        #expect(await search.requestedRadii() == [5_000])
    }

    private func coordinate(latitude: Double, longitude: Double) -> GeographicCoordinate {
        GeographicCoordinate(latitudeDegrees: latitude, longitudeDegrees: longitude)!
    }
}
