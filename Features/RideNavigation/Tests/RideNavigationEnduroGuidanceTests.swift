import EnvironmentDomain
import Foundation
@testable import RideNavigation
import RideNavigationDomain
import Testing
import TestSupport

@MainActor
struct RideNavigationEnduroGuidanceTests {
    @Test("enduro navigation shows rider, arrow, and traveled breadcrumb")
    func enduroNavigationShowsLiveTrailState() async {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let start = coordinate(latitude: 41)
        let next = coordinate(latitude: 41.0001)
        let route = RideRoute(
            name: "Enduro trail",
            createdAt: date,
            segments: [
                RideRouteSegment(points: [
                    routePoint(start, date: date),
                    routePoint(coordinate(latitude: 41.002), date: date)
                ])
            ]
        )
        let fixture = RideNavigationViewModelFixture(routes: [route])

        fixture.viewModel.start()
        await fixture.deviceSpeedRepository.send(sample(start, date: date, courseDegrees: 0))
        #expect(await waitUntil { fixture.viewModel.viewState.savedRoutes.count == 1 })

        fixture.viewModel.openSavedRoute(id: route.id)
        fixture.viewModel.startPreviewedRoute()
        #expect(await waitUntil { fixture.viewModel.viewState.activity == .following })
        await fixture.deviceSpeedRepository.send(
            sample(next, date: date.addingTimeInterval(5), courseDegrees: 90)
        )

        #expect(await waitUntil {
            fixture.viewModel.viewState.guidance?.text == "ENDURO · FOLLOW THE ARROW"
                && fixture.viewModel.viewState.mapScene.userCoordinate == mapCoordinate(next)
                && fixture.viewModel.viewState.mapScene.polylines.contains {
                    $0.role == .trailCompleted && $0.points.count >= 2
                }
        })
        #expect(fixture.viewModel.viewState.activity == .following)
        #expect(fixture.viewModel.viewState.mapScene.userCoordinate == mapCoordinate(next))
        #expect((fixture.viewModel.viewState.guidance?.rotationDegrees ?? .zero) < -80)
        #expect(!(await fixture.roadRouteCalculator.hasPendingRequest))
        #expect(fixture.viewModel.viewState.mapScene.displayStyle == .focus)

        fixture.viewModel.stop()
    }

    @Test("off-trail rejoin dots only appear for a GPX in Focus")
    func rejoinGuideIsFocusOnly() async {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let start = coordinate(latitude: 41)
        let route = RideRoute(
            name: "Enduro trail",
            createdAt: date,
            segments: [
                RideRouteSegment(points: [
                    routePoint(start, date: date),
                    routePoint(coordinate(latitude: 41.01), date: date)
                ])
            ]
        )
        let fixture = RideNavigationViewModelFixture(routes: [route])
        fixture.viewModel.start()
        await fixture.deviceSpeedRepository.send(sample(start, date: date, courseDegrees: .zero))
        #expect(await waitUntil {
            fixture.viewModel.viewState.savedRoutes.count == 1
                && fixture.viewModel.viewState.mapScene.userCoordinate == mapCoordinate(start)
        })
        fixture.viewModel.openSavedRoute(id: route.id)
        fixture.viewModel.startPreviewedRoute()
        #expect(await waitUntil { fixture.viewModel.viewState.activity == .following })

        let offTrail = coordinate(latitude: 41.002, longitude: 2.002)
        await fixture.deviceSpeedRepository.send(sample(offTrail, date: date, courseDegrees: .zero))

        #expect(await waitUntil {
            fixture.viewModel.viewState.guidance?.text == "OFF TRAIL"
                && fixture.viewModel.viewState.mapScene.polylines.contains { $0.role == .rejoinGuide }
        })

        fixture.viewModel.setMapStyle(MapSourceDescriptor.appleStandard.id)
        #expect(!fixture.viewModel.viewState.mapScene.polylines.contains { $0.role == .rejoinGuide })
        fixture.viewModel.stop()
    }

    @Test("ending a trail manually does not report an arrival")
    func manualTrailEndHasExplicitReason() async {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let start = coordinate(latitude: 41)
        let route = RideRoute(
            name: "Enduro trail",
            createdAt: date,
            segments: [
                RideRouteSegment(points: [
                    routePoint(start, date: date),
                    routePoint(coordinate(latitude: 41.01), date: date)
                ])
            ]
        )
        let fixture = RideNavigationViewModelFixture(routes: [route])
        fixture.viewModel.start()
        await fixture.deviceSpeedRepository.send(sample(start, date: date, courseDegrees: .zero))
        #expect(await waitUntil { fixture.viewModel.viewState.savedRoutes.count == 1 })
        fixture.viewModel.openSavedRoute(id: route.id)
        fixture.viewModel.startPreviewedRoute()
        #expect(await waitUntil { fixture.viewModel.viewState.activity == .following })

        fixture.viewModel.finishActivity()

        #expect(fixture.viewModel.viewState.summaryTitle == "Trail ended")
        #expect(await fixture.guidance.recordedSuccessCount() == 0)
        fixture.viewModel.stop()
    }

    @Test("trail exit preview keeps the GPX active until confirmed and can resume it")
    func trailExitCanStartAndResume() async {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let start = coordinate(latitude: 41)
        let exitCoordinate = coordinate(latitude: 41.003, longitude: 2.001)
        let route = RideRoute(
            name: "Enduro trail",
            createdAt: date,
            segments: [
                RideRouteSegment(points: [
                    routePoint(start, date: date),
                    routePoint(coordinate(latitude: 41.01), date: date)
                ])
            ]
        )
        let exit = TrailExitRoute(
            destination: NavigationPlace(
                name: "Mountain parking",
                detail: "Apple Maps",
                coordinate: exitCoordinate
            ),
            route: RoadNavigationRoute(
                name: "Exit route",
                points: [start, exitCoordinate],
                distanceMeters: 500,
                expectedTravelTime: 180,
                steps: []
            )
        )
        let fixture = RideNavigationViewModelFixture(
            routes: [route],
            trailExitFinder: StubTrailExitFinder(result: exit)
        )
        fixture.viewModel.start()
        await fixture.deviceSpeedRepository.send(sample(start, date: date, courseDegrees: .zero))
        #expect(await waitUntil {
            fixture.viewModel.viewState.savedRoutes.count == 1
                && fixture.viewModel.viewState.mapScene.userCoordinate == mapCoordinate(start)
        })
        fixture.viewModel.openSavedRoute(id: route.id)
        fixture.viewModel.startPreviewedRoute()
        #expect(await waitUntil { fixture.viewModel.viewState.activity == .following })

        fixture.viewModel.findTrailExit()
        #expect(await waitUntil {
            fixture.viewModel.viewState.trailExitPreview?.title == "Mountain parking"
        })
        #expect(fixture.viewModel.viewState.activity == .following)

        fixture.viewModel.startTrailExit()
        #expect(fixture.viewModel.viewState.activity == .navigating)
        #expect(fixture.viewModel.viewState.canResumeGPX)

        fixture.viewModel.resumeGPX()
        #expect(fixture.viewModel.viewState.activity == .following)
        #expect(!fixture.viewModel.viewState.canResumeGPX)
        fixture.viewModel.stop()
    }

    private func sample(
        _ coordinate: GeographicCoordinate,
        date: Date,
        courseDegrees: Double
    ) -> DeviceSpeedSample {
        DeviceSpeedSample(
            kilometersPerHour: 20,
            accuracyMetersPerSecond: 1,
            courseDegrees: courseDegrees,
            courseAccuracyDegrees: 5,
            horizontalAccuracyMeters: 5,
            coordinate: coordinate,
            observedAt: date
        )
    }

    private func routePoint(
        _ coordinate: GeographicCoordinate,
        date: Date
    ) -> RideRoutePoint {
        RideRoutePoint(
            coordinate: coordinate,
            timestamp: date,
            horizontalAccuracyMeters: 5
        )
    }

    private func coordinate(
        latitude: Double,
        longitude: Double = 2
    ) -> GeographicCoordinate {
        GeographicCoordinate(latitudeDegrees: latitude, longitudeDegrees: longitude)!
    }

    private func mapCoordinate(_ coordinate: GeographicCoordinate) -> NavigationMapCoordinate? {
        NavigationMapCoordinate(
            latitudeDegrees: coordinate.latitudeDegrees,
            longitudeDegrees: coordinate.longitudeDegrees
        )
    }
}
