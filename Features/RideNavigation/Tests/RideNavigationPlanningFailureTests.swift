import EnvironmentDomain
import Foundation
@testable import RideNavigation
import RideNavigationDomain
import Testing
import TestSupport

@MainActor
struct RideNavigationPlanningFailureTests {
    @Test("a destination without current location reports an error without requesting routes")
    func missingLocation() async throws {
        let fixture = RideNavigationViewModelFixture()
        defer { fixture.viewModel.stop() }
        let destination = try await selectDestination(fixture: fixture, includesLocation: false)

        fixture.viewModel.selectSearchResult(id: destination.id)

        #expect(fixture.viewModel.viewState.errorText != nil)
        #expect(!fixture.viewModel.viewState.isCalculatingRoadRoutes)
        #expect(await fixture.roadRouteCalculator.requestCount == 0)
    }

    @Test("offline and empty route responses clear loading and leave navigation inactive", arguments: [true, false])
    func unavailableRoutes(isOffline: Bool) async throws {
        let fixture = RideNavigationViewModelFixture()
        defer { fixture.viewModel.stop() }
        let destination = try await selectDestination(fixture: fixture, includesLocation: true)
        fixture.viewModel.selectSearchResult(id: destination.id)
        #expect(await waitUntil { await fixture.roadRouteCalculator.hasPendingRequest })

        if isOffline {
            await fixture.roadRouteCalculator.fail(request: 0, error: URLError(.notConnectedToInternet))
        } else {
            await fixture.roadRouteCalculator.succeed(routes: [])
        }

        #expect(await waitUntil { !fixture.viewModel.viewState.isCalculatingRoadRoutes })
        #expect(fixture.viewModel.viewState.errorText != nil)
        #expect(fixture.viewModel.viewState.roadRouteOptions.isEmpty)
        #expect(!fixture.viewModel.viewState.isSearching)
        #expect(fixture.viewModel.viewState.guidance == nil)
    }

    private func selectDestination(
        fixture: RideNavigationViewModelFixture,
        includesLocation: Bool
    ) async throws -> NavigationPlace {
        let coordinate = try #require(GeographicCoordinate(latitudeDegrees: 40.4, longitudeDegrees: -3.7))
        let destination = NavigationPlace(name: "Destination", detail: "Test location", coordinate: coordinate)
        fixture.viewModel.start()
        if includesLocation {
            await fixture.deviceSpeedRepository.send(DeviceSpeedSample(
                kilometersPerHour: 0,
                accuracyMetersPerSecond: 1,
                courseDegrees: 0,
                courseAccuracyDegrees: 5,
                horizontalAccuracyMeters: 5,
                coordinate: coordinate,
                observedAt: Date(timeIntervalSince1970: 1_700_000_000)
            ))
        }
        fixture.viewModel.updateSearchQuery("Destination")
        #expect(await waitUntil { await fixture.placeSearch.hasRequest(for: "Destination") })
        await fixture.placeSearch.succeed(query: "Destination", places: [destination])
        #expect(await waitUntil { fixture.viewModel.viewState.searchResults.count == 1 })
        return destination
    }
}
