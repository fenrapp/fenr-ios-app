import EnvironmentDomain
import Foundation
@testable import RideNavigation
import RideNavigationDomain
import SettingsDomain
import Testing
import TestSupport

@MainActor
struct RideNavigationMiniModeTests {
    @Test("mini navigation applies shared settings updates live")
    func miniNavigationObservesSharedSettings() async {
        let fixture = RideNavigationViewModelFixture()
        fixture.viewModel.start()
        fixture.viewModel.setPresentationMode(.mini)
        #expect(await waitUntil { await fixture.settingsRepository.waitForSubscriber() })

        await fixture.settingsRepository.publish(
            AppSettings(
                rideNavigation: RideNavigationSettings(
                    showsGuidanceInFocus: true,
                    showsCompassRing: true,
                    showsRoadsInFocus: true
                )
            )
        )

        #expect(await waitUntil {
            fixture.viewModel.miniViewState.mapScene.showsCompassRing
                && fixture.viewModel.miniViewState.mapScene.showsRoadsInFocus
        })
        fixture.viewModel.stop()
    }

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
            fixture.viewModel.miniViewState.mapScene.userCoordinate == mapCoordinate(next)
        })
        #expect(fixture.viewModel.miniViewState.mapScene.polylines.contains {
            $0.role == .trailCompleted && $0.points.count >= 2
        })
        guard case .follow(_, let heading) = fixture.viewModel.miniViewState.mapScene.camera else {
            Issue.record("Mini navigation should follow the latest route location")
            fixture.viewModel.stop()
            return
        }
        #expect(heading == 90)
        #expect(fixture.viewModel.miniViewState.mapScene.markers.isEmpty)
        fixture.viewModel.stop()
    }

    @Test("mini map settings persist in order with the latest values")
    func miniMapSettingsPersistenceIsLatestWriteWins() async {
        let fixture = RideNavigationViewModelFixture()
        let firstPosition = RideNavigationMiniViewState.Position(
            horizontalFraction: 0.02,
            verticalFraction: 0.98
        )
        let latestPosition = RideNavigationMiniViewState.Position(
            horizontalFraction: 0.8,
            verticalFraction: 0.2
        )

        await fixture.settingsRepository.suspendNextSave()
        fixture.viewModel.setMiniMapPosition(firstPosition)
        await fixture.settingsRepository.waitUntilSaveIsSuspended()

        fixture.viewModel.setMiniMapPosition(latestPosition)
        fixture.viewModel.setMiniMapScale(1.5)
        fixture.viewModel.toggleMiniMapLayoutOrientation()
        #expect(await fixture.settingsRepository.saveInvocationCount() == 1)

        await fixture.settingsRepository.resumeSuspendedSave()
        #expect(await waitUntil {
            await fixture.settingsRepository.savedSettings().count == 2
        })

        let savedSettings = await fixture.settingsRepository.savedSettings()
        #expect(
            savedSettings.first?.rideNavigation.miniMapPosition.horizontalFraction
                == firstPosition.horizontalFraction
        )
        #expect(
            savedSettings.first?.rideNavigation.miniMapPosition.verticalFraction
                == firstPosition.verticalFraction
        )
        #expect(
            savedSettings.last?.rideNavigation.miniMapPosition.horizontalFraction
                == latestPosition.horizontalFraction
        )
        #expect(
            savedSettings.last?.rideNavigation.miniMapPosition.verticalFraction
                == latestPosition.verticalFraction
        )
        #expect(savedSettings.last?.rideNavigation.miniMapScale.value == 1.5)
        #expect(savedSettings.last?.rideNavigation.miniMapLayoutOrientation == .landscape)
        #expect(fixture.viewModel.miniViewState.position == latestPosition)
        #expect(fixture.viewModel.miniViewState.scale == 1.5)
        #expect(fixture.viewModel.miniViewState.scaleRange == 0.5 ... 1.5)
        #expect(fixture.viewModel.miniViewState.isLandscape)
        fixture.viewModel.stop()
    }

    @Test("mini map layout keeps every edge inside the screen margin")
    func miniMapLayoutRespectsScreenMargins() {
        let layout = RideNavigationMiniMapLayout(
            containerSize: CGSize(width: 900, height: 400),
            scale: 1.5,
            isLandscape: false
        )
        let topLeading = layout.position(for: .init(horizontalFraction: 0, verticalFraction: 0))
        let bottomTrailing = layout.position(for: .init(horizontalFraction: 1, verticalFraction: 1))

        #expect(abs(topLeading.x - layout.cardSize.width / 2 - 16) < 0.001)
        #expect(abs(topLeading.y - layout.cardSize.height / 2 - 44 - 16) < 0.001)
        #expect(abs(900 - bottomTrailing.x - layout.cardSize.width / 2 - 16) < 0.001)
        #expect(abs(400 - bottomTrailing.y - layout.cardSize.height / 2 - 16) < 0.001)
    }

    @Test("mini map layout rotates and scales within its supported range")
    func miniMapLayoutRotatesAndScales() {
        let compact = RideNavigationMiniMapLayout(
            containerSize: CGSize(width: 900, height: 400),
            scale: 0.5,
            isLandscape: false
        )
        let expanded = RideNavigationMiniMapLayout(
            containerSize: CGSize(width: 900, height: 400),
            scale: 1.5,
            isLandscape: true
        )

        #expect(compact.cardSize.height > compact.cardSize.width)
        #expect(expanded.cardSize.width > expanded.cardSize.height)
        #expect(expanded.cardSize.width > compact.cardSize.width)
    }

    @Test("mini map drag preserves the original pickup point")
    func miniMapDragUsesTranslationFromItsRestingPosition() {
        let layout = RideNavigationMiniMapLayout(
            containerSize: CGSize(width: 900, height: 400),
            scale: 1,
            isLandscape: true
        )
        let origin = CGPoint(x: 400, y: 220)
        let translated = layout.translatedPosition(
            from: origin,
            by: CGSize(width: 75, height: -30)
        )

        #expect(translated == CGPoint(x: 475, y: 190))
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
            fixture.viewModel.miniViewState.statusText == "END REACHED · TAP"
        })
        #expect(await fixture.deviceSpeedRepository.activeObserverCount() == 1)

        fixture.viewModel.setPresentationMode(.fullScreen)
        #expect(fixture.viewModel.viewState.screen == .map)
        #expect(fixture.viewModel.viewState.arrivalPrompt != nil)
        fixture.viewModel.finishAfterTrailArrival()
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
            deviceSpeedSample(coordinate, seconds: .zero, courseDegrees: 0)
        )
        #expect(await waitUntil {
            fixture.viewModel.viewState.savedRoutes.count == 1
                && fixture.viewModel.viewState.mapScene.userCoordinate == mapCoordinate(coordinate)
        })
        fixture.viewModel.openSavedRoute(id: route.id)
        fixture.viewModel.startPreviewedRoute()
        #expect(await waitUntil { fixture.viewModel.viewState.activity == .following })
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

    private func mapCoordinate(_ coordinate: GeographicCoordinate) -> NavigationMapCoordinate? {
        NavigationMapCoordinate(
            latitudeDegrees: coordinate.latitudeDegrees,
            longitudeDegrees: coordinate.longitudeDegrees
        )
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

extension RideNavigationMiniModeTests {
    @Test("mini orientation control stays inside the card and below the dashboard header",
          arguments: [0.5, 1.0, 1.5], [false, true])
    func miniOrientationControlStaysInsideCard(scale: Double, isLandscape: Bool) {
        for size in [CGSize(width: 667, height: 375), CGSize(width: 874, height: 402)] {
            let layout = RideNavigationMiniMapLayout(
                containerSize: size, scale: scale, isLandscape: isLandscape
            )
            for fraction in [0.0, 1.0] {
                let center = layout.position(for: .init(horizontalFraction: fraction, verticalFraction: fraction))
                let card = CGRect(
                    x: center.x - layout.cardSize.width / 2,
                    y: center.y - layout.cardSize.height / 2,
                    width: layout.cardSize.width, height: layout.cardSize.height
                )
                let controlCenter = layout.orientationControlPosition(for: center)
                let hitSize = RideNavigationMiniMapLayout.orientationControlHitSize
                let control = CGRect(
                    x: controlCenter.x - hitSize / 2, y: controlCenter.y - hitSize / 2,
                    width: hitSize, height: hitSize
                )

                #expect(card.contains(control))
                #expect(control.minY > card.minY)
                #expect(control.maxY < card.maxY)
                #expect(control.maxX < card.maxX)
                #expect(card.minY >= 60 - 0.001)
            }
        }
    }
}
