import EnvironmentDomain
import Foundation
@testable import RideNavigation
import RideNavigationDomain
import SettingsDomain
import Testing
import TestSupport

@MainActor
struct RideNavigationRoadGuidanceTests {
    @Test("route preferences persist, recalculate alternatives, and drive the active map style")
    func preferencesAndFocusStyle() async throws {
        let fixture = RideNavigationViewModelFixture()
        let context = try await prepareRoadPreview(fixture: fixture)

        fixture.viewModel.setAvoidsTolls(true)
        #expect(await waitUntil { await fixture.roadRouteCalculator.hasPendingRequest })
        #expect(await fixture.roadRouteCalculator.lastPreferences?.avoidsTolls == true)
        await fixture.roadRouteCalculator.succeed(routes: [context.route])
        #expect(await waitUntil { !fixture.viewModel.viewState.isCalculatingRoadRoutes })
        #expect(await waitUntil {
            await fixture.settingsRepository.load().rideNavigation.avoidsTolls
        })

        fixture.viewModel.startPreviewedRoute()
        #expect(fixture.viewModel.viewState.mapScene.displayStyle == .focus)
        #expect(fixture.viewModel.viewState.allowsFocusMapStyle)
        #expect(fixture.viewModel.viewState.isHeadingUp)

        fixture.viewModel.setMapHeadingUp(false)
        #expect(!fixture.viewModel.viewState.isHeadingUp)
        guard case .follow(_, let heading) = fixture.viewModel.viewState.mapScene.camera else {
            Issue.record("Selecting North Up should return to the follow camera")
            return
        }
        #expect(heading == nil)
        #expect(await waitUntil {
            await fixture.settingsRepository.load().rideNavigation.mapOrientation == .northUp
        })

        fixture.viewModel.setMapStyle(MapSourceDescriptor.appleHybrid.id)
        #expect(fixture.viewModel.viewState.mapScene.displayStyle == .map)
        #expect(fixture.viewModel.viewState.mapScene.source == .appleHybrid)
        #expect(await waitUntil {
            await fixture.settingsRepository.load().rideNavigation.preferredMapStyle == .satellite
        })
        fixture.viewModel.stop()
    }

    @Test("road guidance advances monotonically and reroutes with the saved preferences")
    func roadStepProgressAndReroute() async throws {
        let settings = AppSettings(
            rideNavigation: RideNavigationSettings(avoidsTolls: true, avoidsHighways: true)
        )
        let fixture = RideNavigationViewModelFixture(settings: settings)
        let context = try await prepareRoadPreview(fixture: fixture, routeWithSteps: true)
        fixture.viewModel.startPreviewedRoute()

        await fixture.deviceSpeedRepository.send(
            deviceSpeedSample(context.maneuver, observedAt: Date(timeIntervalSince1970: 1_700_000_005))
        )
        #expect(await waitUntil { fixture.viewModel.viewState.guidance?.text == "Continue straight" })

        fixture.viewModel.setPresentationMode(.mini)
        let offRoute = coordinate(latitude: 41.01, longitude: 2.01)
        await fixture.deviceSpeedRepository.send(
            deviceSpeedSample(offRoute, observedAt: Date(timeIntervalSince1970: 1_700_000_010))
        )
        #expect(await waitUntil { await fixture.roadRouteCalculator.hasPendingRequest })
        #expect(await fixture.roadRouteCalculator.lastPreferences == RoadRoutePreferences(
            avoidsTolls: true,
            avoidsHighways: true
        ))
        #expect(fixture.viewModel.miniViewState.statusText == "REROUTING")

        await fixture.roadRouteCalculator.succeed(routes: [context.route])
        #expect(await waitUntil { fixture.viewModel.miniViewState.statusText == nil })
        fixture.viewModel.stop()
    }

    @Test("ending road navigation manually does not report destination reached")
    func manualRoadEndHasExplicitReason() async throws {
        let fixture = RideNavigationViewModelFixture()
        _ = try await prepareRoadPreview(fixture: fixture)
        fixture.viewModel.startPreviewedRoute()

        fixture.viewModel.finishActivity()

        #expect(fixture.viewModel.viewState.summaryTitle == "Navigation ended")
        #expect(await fixture.guidance.recordedSuccessCount() == 0)
        fixture.viewModel.stop()
    }

    @Test("a reroute result cannot replace the summary after navigation ends")
    func rerouteResultIsIgnoredAfterFinishing() async throws {
        let fixture = RideNavigationViewModelFixture()
        let context = try await prepareRoadPreview(fixture: fixture)
        fixture.viewModel.startPreviewedRoute()
        await fixture.deviceSpeedRepository.send(
            deviceSpeedSample(
                coordinate(latitude: 41.01, longitude: 2.01),
                observedAt: Date(timeIntervalSince1970: 1_700_000_010)
            )
        )
        #expect(await waitUntil { await fixture.roadRouteCalculator.hasPendingRequest })

        fixture.viewModel.finishActivity()
        await fixture.roadRouteCalculator.succeed(routes: [context.route])
        #expect(await waitUntil { await fixture.roadRouteCalculator.completionCount == 2 })

        #expect(fixture.viewModel.viewState.screen == .summary)
        #expect(fixture.viewModel.viewState.summaryTitle == "Navigation ended")
        #expect(!fixture.viewModel.viewState.isRerouting)
        fixture.viewModel.stop()
    }

    private func prepareRoadPreview(
        fixture: RideNavigationViewModelFixture,
        routeWithSteps: Bool = false
    ) async throws -> RoadContext {
        let origin = coordinate(latitude: 41, longitude: 2)
        let maneuver = coordinate(latitude: 41.0002, longitude: 2)
        let destinationCoordinate = coordinate(latitude: 41.001, longitude: 2.0002)
        let destination = NavigationPlace(
            name: "Destination",
            detail: "Barcelona",
            coordinate: destinationCoordinate
        )
        let steps = routeWithSteps ? [
            RoadNavigationStep(
                instruction: "Turn right",
                distanceMeters: 25,
                points: [origin, maneuver]
            ),
            RoadNavigationStep(
                instruction: "Continue straight",
                distanceMeters: 100,
                points: [maneuver, destinationCoordinate]
            )
        ] : []
        let route = RoadNavigationRoute(
            name: "Calculated route",
            points: [origin, maneuver, destinationCoordinate],
            distanceMeters: 125,
            expectedTravelTime: 90,
            steps: steps
        )

        fixture.viewModel.start()
        await fixture.deviceSpeedRepository.send(
            deviceSpeedSample(origin, observedAt: Date(timeIntervalSince1970: 1_700_000_000))
        )
        fixture.viewModel.updateSearchQuery("Destination")
        #expect(await waitUntil { await fixture.placeSearch.hasRequest(for: "Destination") })
        await fixture.placeSearch.succeed(query: "Destination", places: [destination])
        #expect(await waitUntil { fixture.viewModel.viewState.searchResults.count == 1 })
        fixture.viewModel.selectSearchResult(id: destination.id)
        #expect(await waitUntil { await fixture.roadRouteCalculator.hasPendingRequest })
        await fixture.roadRouteCalculator.succeed(routes: [route])
        #expect(await waitUntil { fixture.viewModel.viewState.roadRouteOptions.count == 1 })
        return RoadContext(route: route, maneuver: maneuver)
    }

    private func deviceSpeedSample(
        _ coordinate: GeographicCoordinate,
        observedAt: Date
    ) -> DeviceSpeedSample {
        DeviceSpeedSample(
            kilometersPerHour: 30,
            accuracyMetersPerSecond: 1,
            courseDegrees: .zero,
            courseAccuracyDegrees: 5,
            horizontalAccuracyMeters: 5,
            coordinate: coordinate,
            observedAt: observedAt
        )
    }

    private func coordinate(latitude: Double, longitude: Double) -> GeographicCoordinate {
        GeographicCoordinate(latitudeDegrees: latitude, longitudeDegrees: longitude)!
    }
}

private struct RoadContext {
    let route: RoadNavigationRoute
    let maneuver: GeographicCoordinate
}
