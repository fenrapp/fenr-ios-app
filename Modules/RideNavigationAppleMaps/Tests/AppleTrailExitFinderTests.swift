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

    @Test("expands the search radii until eight unique candidates are found")
    func expandsSearchAcrossRadiiUntilEightUniqueCandidates() async throws {
        let origin = coordinate(latitude: 41, longitude: 2)
        let candidates = (0 ..< 8).map(place)
        let search = RecordingTrailExitCandidateSearch(resultsByRadius: [
            5_000: [candidates[0], candidates[1], candidates[1]],
            15_000: [candidates[1], candidates[2], candidates[3], candidates[4]],
            40_000: [candidates[4], candidates[5], candidates[6], candidates[7]]
        ])
        let routeCalculator = RecordingTrailExitRouteCalculator(
            values: Dictionary(uniqueKeysWithValues: candidates.enumerated().map { index, candidate in
                (candidate.name, .init(distanceMeters: Double(index + 1) * 100, travelTime: 60))
            })
        )
        let finder = AppleTrailExitFinder(
            candidateSearch: search,
            roadRouteCalculator: routeCalculator
        )

        _ = try await finder.findExit(from: origin, preferences: .init())

        #expect(await search.requestedRadii() == [5_000, 15_000, 40_000])
        #expect(await routeCalculator.requestedDestinations().count == 8)
    }

    @Test("skips unavailable routes and chooses the shortest reachable exit")
    func skipsUnavailableRoutesAndChoosesShortestReachable() async throws {
        let candidates = [place(0), place(1), place(2)]
        let routeCalculator = RecordingTrailExitRouteCalculator(outcomes: [
            candidates[0].name: .unavailable,
            candidates[1].name: .route(.init(distanceMeters: 900, travelTime: 100)),
            candidates[2].name: .route(.init(distanceMeters: 700, travelTime: 200))
        ])
        let finder = AppleTrailExitFinder(
            candidateSearch: RecordingTrailExitCandidateSearch(results: candidates),
            roadRouteCalculator: routeCalculator
        )

        let exit = try await finder.findExit(
            from: coordinate(latitude: 41, longitude: 2),
            preferences: .init()
        )

        #expect(exit.destination.name == candidates[2].name)
        #expect(await routeCalculator.requestedDestinations() == candidates.map(\.name))
    }

    @Test("uses travel time to break equal-distance route ties")
    func usesTravelTimeToBreakEqualDistance() async throws {
        let candidates = [place(0), place(1)]
        let routeCalculator = RecordingTrailExitRouteCalculator(values: [
            candidates[0].name: .init(distanceMeters: 800, travelTime: 240),
            candidates[1].name: .init(distanceMeters: 800, travelTime: 120)
        ])
        let finder = AppleTrailExitFinder(
            candidateSearch: RecordingTrailExitCandidateSearch(results: candidates),
            roadRouteCalculator: routeCalculator
        )

        let exit = try await finder.findExit(
            from: coordinate(latitude: 41, longitude: 2),
            preferences: .init()
        )

        #expect(exit.destination.name == candidates[1].name)
    }

    @Test("propagates cancellation without trying remaining candidates")
    func propagatesCancellationWithoutTryingRemainingCandidates() async throws {
        let candidates = [place(0), place(1)]
        let routeCalculator = RecordingTrailExitRouteCalculator(outcomes: [
            candidates[0].name: .cancellation,
            candidates[1].name: .route(.init(distanceMeters: 100, travelTime: 20))
        ])
        let finder = AppleTrailExitFinder(
            candidateSearch: RecordingTrailExitCandidateSearch(results: candidates),
            roadRouteCalculator: routeCalculator
        )

        await #expect(throws: CancellationError.self) {
            _ = try await finder.findExit(
                from: coordinate(latitude: 41, longitude: 2),
                preferences: .init()
            )
        }
        #expect(await routeCalculator.requestedDestinations() == [candidates[0].name])
    }

    private func place(_ index: Int) -> NavigationPlace {
        NavigationPlace(
            name: "Candidate \(index)",
            detail: "Apple Maps",
            coordinate: coordinate(
                latitude: 41 + Double(index + 1) * 0.001,
                longitude: 2
            )
        )
    }

    private func coordinate(latitude: Double, longitude: Double) -> GeographicCoordinate {
        GeographicCoordinate(latitudeDegrees: latitude, longitudeDegrees: longitude)!
    }
}
