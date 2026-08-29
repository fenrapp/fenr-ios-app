import EnvironmentDomain
import Foundation
@testable import RideNavigationDomain
import Testing

struct RoadNavigationRouteTests {
    @Test
    func defaultRouteSelectionUsesFirstAlternative() async throws {
        let routes = [route(name: "Recommended", offset: .zero), route(name: "Alternative", offset: 0.01)]
        let calculator = StubRoadRouteCalculator(stubbedRoutes: routes)

        let selected = try await calculator.route(
            from: coordinate(),
            to: destination(),
            preferences: .init()
        )

        #expect(selected == routes[0])
    }

    @Test
    func defaultRouteSelectionRejectsAnEmptyResponse() async {
        let calculator = StubRoadRouteCalculator(stubbedRoutes: [])

        await #expect(throws: RoadRouteCalculationError.self) {
            try await calculator.route(
                from: coordinate(),
                to: destination(),
                preferences: .init()
            )
        }
    }

    @Test
    func exportRoutePreservesCalculatedGeometry() throws {
        let calculated = route(name: "Calculated", offset: .zero)
        let createdAt = Date(timeIntervalSince1970: 1_000)

        let exported = try #require(calculated.exportRoute(name: "Destination", createdAt: createdAt))

        #expect(exported.name == "Destination")
        #expect(exported.createdAt == createdAt)
        #expect(exported.points.map(\.coordinate) == calculated.points)
    }

    private func route(name: String, offset: Double) -> RoadNavigationRoute {
        RoadNavigationRoute(
            name: name,
            points: [coordinate(offset: offset), coordinate(offset: offset + 0.001)],
            distanceMeters: 1_000,
            expectedTravelTime: 120,
            steps: []
        )
    }

    private func destination() -> NavigationPlace {
        NavigationPlace(name: "Destination", detail: "Test", coordinate: coordinate(offset: 0.02))
    }

    private func coordinate(offset: Double = .zero) -> GeographicCoordinate {
        GeographicCoordinate(latitudeDegrees: 41 + offset, longitudeDegrees: 2 + offset)!
    }
}
