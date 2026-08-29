import EnvironmentDomain
import Foundation
@testable import RideNavigation
import RideNavigationDomain
import Testing
import TestSupport

@MainActor
struct RideNavigationMiniModeTests {
    @Test("mini GPX keeps route progress without motorcycle metrics")
    func miniGPXUsesTheLocationStream() async {
        let context = makeRoute(name: "Mini trail", finishLatitude: 41.01)
        let next = coordinate(latitude: 41.0002)
        let fixture = RideNavigationViewModelFixture(routes: [context.route])
        await start(context.route, at: context.start, fixture: fixture)

        fixture.viewModel.setPresentationMode(.mini)
        await fixture.deviceSpeedRepository.send(
            deviceSpeedSample(next, seconds: 5, courseDegrees: 90)
        )

        #expect(await waitUntil {
            fixture.viewModel.miniViewState.mapScene.userCoordinate == next
        })
        #expect(fixture.viewModel.miniViewState.mapScene.polylines.contains {
            $0.role == .completed && $0.points.count >= 2
        })
        #expect(fixture.viewModel.miniViewState.mapScene.displayStyle == .focus)
        #expect(fixture.viewModel.miniViewState.mapScene.markers.isEmpty)

        fixture.viewModel.setMiniMapCorner(.bottomLeading)
        #expect(await waitUntil {
            await fixture.settingsRepository.load().rideNavigation.miniMapCorner == .bottomLeading
        })
        fixture.viewModel.stop()
    }

    @Test("an automatic trail arrival remains compact until expanded")
    func miniArrivalWaitsForExpansion() async {
        let context = makeRoute(name: "Short trail", finishLatitude: 41.001)
        let fixture = RideNavigationViewModelFixture(routes: [context.route])
        await start(context.route, at: context.start, fixture: fixture)
        fixture.viewModel.setPresentationMode(.mini)

        await fixture.deviceSpeedRepository.send(
            deviceSpeedSample(context.finish, seconds: 10, courseDegrees: .zero)
        )
        #expect(await waitUntil {
            fixture.viewModel.miniViewState.statusText == "Trail complete"
        })
        #expect(await waitUntil { await fixture.deviceSpeedRepository.activeObserverCount() == 0 })

        fixture.viewModel.setPresentationMode(.fullScreen)
        #expect(fixture.viewModel.viewState.screen == .summary)
        #expect(fixture.viewModel.viewState.summaryTitle == "Trail complete")
        fixture.viewModel.stop()
    }

    private func start(
        _ route: RideRoute,
        at coordinate: GeographicCoordinate,
        fixture: RideNavigationViewModelFixture
    ) async {
        fixture.viewModel.start()
        await fixture.deviceSpeedRepository.send(
            deviceSpeedSample(coordinate, seconds: .zero, courseDegrees: 90)
        )
        #expect(await waitUntil {
            fixture.viewModel.viewState.savedRoutes.count == 1
                && fixture.viewModel.viewState.mapScene.userCoordinate == coordinate
        })
        fixture.viewModel.openSavedRoute(id: route.id)
        fixture.viewModel.startPreviewedRoute()
    }

    private func makeRoute(name: String, finishLatitude: Double) -> RouteContext {
        let date = Date(timeIntervalSince1970: Constants.referenceTime)
        let start = coordinate(latitude: 41)
        let finish = coordinate(latitude: finishLatitude)
        let route = RideRoute(
            name: name,
            createdAt: date,
            segments: [
                RideRouteSegment(points: [
                    routePoint(start, date: date),
                    routePoint(finish, date: date)
                ])
            ]
        )
        return RouteContext(route: route, start: start, finish: finish)
    }

    private func deviceSpeedSample(
        _ coordinate: GeographicCoordinate,
        seconds: TimeInterval,
        courseDegrees: Double
    ) -> DeviceSpeedSample {
        DeviceSpeedSample(
            kilometersPerHour: 20,
            accuracyMetersPerSecond: 1,
            courseDegrees: courseDegrees,
            courseAccuracyDegrees: 5,
            altitudeMeters: 400,
            horizontalAccuracyMeters: 5,
            coordinate: coordinate,
            observedAt: Date(timeIntervalSince1970: Constants.referenceTime + seconds)
        )
    }

    private func routePoint(_ coordinate: GeographicCoordinate, date: Date) -> RideRoutePoint {
        RideRoutePoint(coordinate: coordinate, timestamp: date, horizontalAccuracyMeters: 5)
    }

    private func coordinate(latitude: Double) -> GeographicCoordinate {
        GeographicCoordinate(latitudeDegrees: latitude, longitudeDegrees: 2)!
    }

    private struct RouteContext {
        let route: RideRoute
        let start: GeographicCoordinate
        let finish: GeographicCoordinate
    }

    private enum Constants {
        static let referenceTime: TimeInterval = 1_700_000_000
    }
}
