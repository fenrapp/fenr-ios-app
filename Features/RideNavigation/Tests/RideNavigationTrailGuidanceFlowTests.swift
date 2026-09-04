import EnvironmentDomain
import Foundation
@testable import RideNavigation
import RideNavigationDomain
import Testing
import TestSupport

@MainActor
struct RideNavigationTrailGuidanceFlowTests {
    @Test("reverse intermediate entry asks before changing direction")
    func reverseEntryRequiresConfirmation() async {
        let route = makeRoute(finishLatitude: 41.01)
        let fixture = RideNavigationViewModelFixture(routes: [route])
        fixture.viewModel.start()
        await fixture.deviceSpeedRepository.send(
            sample(coordinate(latitude: 41.005), seconds: 0, courseDegrees: 180)
        )
        #expect(await waitUntil { fixture.viewModel.viewState.savedRoutes.count == 1 })

        fixture.viewModel.openSavedRoute(id: route.id)
        fixture.viewModel.startPreviewedRoute()

        #expect(await waitUntil {
            fixture.viewModel.viewState.trailEntryPrompt?.title == "Follow in reverse?"
        })
        #expect(fixture.viewModel.viewState.activity == .preview)

        fixture.viewModel.selectTrailDirection(.reverse)

        #expect(await waitUntil { fixture.viewModel.viewState.activity == .following })
        #expect(fixture.viewModel.selectedDirection == .reverse)
        #expect(fixture.viewModel.viewState.gpxProgressText == "50%")
        fixture.viewModel.stop()
    }

    @Test("GPX progress follows the route projection and remains bounded off route")
    func gpxProgressTracksForwardRoute() async {
        let route = makeRoute(finishLatitude: 41.001)
        let fixture = RideNavigationViewModelFixture(routes: [route])
        await start(route, fixture: fixture)
        #expect(fixture.viewModel.viewState.gpxProgressText == "0%")

        await fixture.deviceSpeedRepository.send(
            sample(coordinate(latitude: 41.0005), seconds: 20, courseDegrees: 0)
        )
        #expect(await waitUntil { fixture.viewModel.viewState.gpxProgressText == "50%" })

        await fixture.deviceSpeedRepository.send(
            sample(
                coordinate(latitude: 41.0005, longitude: 2.0007),
                seconds: 30,
                courseDegrees: 0
            )
        )
        #expect(fixture.viewModel.viewState.gpxProgressText == "50%")

        await fixture.deviceSpeedRepository.send(
            sample(coordinate(latitude: 41.001), seconds: 40, courseDegrees: 0)
        )
        #expect(await waitUntil {
            fixture.viewModel.viewState.gpxProgressText == "100%"
                && fixture.viewModel.viewState.arrivalPrompt != nil
        })
        fixture.viewModel.stop()
    }

    @Test("a rider outside the entry threshold approaches the route start")
    func distantEntryUsesRoadApproach() async {
        let route = makeRoute(finishLatitude: 41.01)
        let fixture = RideNavigationViewModelFixture(routes: [route])
        fixture.viewModel.start()
        await fixture.deviceSpeedRepository.send(
            sample(
                coordinate(latitude: 41, longitude: 2.0007),
                seconds: 0,
                courseDegrees: 0
            )
        )
        #expect(await waitUntil { fixture.viewModel.viewState.savedRoutes.count == 1 })

        fixture.viewModel.openSavedRoute(id: route.id)
        fixture.viewModel.startPreviewedRoute()

        #expect(await waitUntil { await fixture.roadRouteCalculator.hasPendingRequest })
        #expect(fixture.viewModel.viewState.activity == .preview)
        #expect(fixture.viewModel.trailGuidance.snapshot.hasActiveSession)
        fixture.viewModel.stop()
    }

    @Test("keeping riding suppresses repeated GPX arrival prompts")
    func keepRidingSuppressesArrivalPrompt() async {
        let route = makeRoute(finishLatitude: 41.001)
        let fixture = RideNavigationViewModelFixture(routes: [route])
        await start(route, fixture: fixture)

        await fixture.deviceSpeedRepository.send(
            sample(coordinate(latitude: 41.001), seconds: 10, courseDegrees: 0)
        )
        #expect(await waitUntil { fixture.viewModel.viewState.arrivalPrompt != nil })

        fixture.viewModel.keepRidingAfterTrailArrival()
        await fixture.deviceSpeedRepository.send(
            sample(coordinate(latitude: 41.001), seconds: 15, courseDegrees: 0)
        )

        #expect(fixture.viewModel.viewState.arrivalPrompt == nil)
        #expect(fixture.viewModel.viewState.activity == .following)
        fixture.viewModel.finishActivity()
        #expect(fixture.viewModel.viewState.screen == .summary)
        fixture.viewModel.stop()
    }

    @Test("an imported plan and completed trace persist with independent identities")
    func plannedAndCompletedRoutesPersistIndependently() async throws {
        let route = makeRoute(finishLatitude: 41.01)
        let repository = ControllableRecordedRouteRepository()
        let fixture = RideNavigationViewModelFixture(
            repository: repository,
            importer: FixedGPXRouteImporter(routes: [route])
        )
        let url = temporaryImportURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("test".utf8).write(to: url)
        fixture.viewModel.start()
        await fixture.deviceSpeedRepository.send(
            sample(coordinate(latitude: 41), seconds: 0, courseDegrees: 0)
        )
        #expect(await waitUntil { fixture.viewModel.viewState.mapScene.userCoordinate != nil })

        fixture.viewModel.importGPX(from: url)
        #expect(await waitUntil { !fixture.viewModel.viewState.isPreparingTrail })
        fixture.viewModel.startPreviewedRoute()
        #expect(await waitUntil { await repository.saveRequestCount == 1 })
        #expect(fixture.viewModel.viewState.activity == .preview)
        await repository.completeSave()
        #expect(await waitUntil { fixture.viewModel.viewState.activity == .following })

        await fixture.deviceSpeedRepository.send(
            sample(coordinate(latitude: 41.0002), seconds: 5, courseDegrees: 0)
        )
        fixture.viewModel.finishActivity()
        #expect(await waitUntil { await repository.saveRequestCount == 1 })
        #expect(fixture.viewModel.viewState.routePersistence == .saving)

        fixture.viewModel.stop()
        await repository.completeSave()
        #expect(await waitUntil { await repository.storedRoutes.count == 2 })
        fixture.viewModel.start()
        #expect(await waitUntil {
            fixture.viewModel.viewState.routePersistence == .saved
                && fixture.viewModel.viewState.savedRoutes.count == 2
        })
        let storedRoutes = await repository.storedRoutes
        #expect(Set(storedRoutes.map(\.id)).count == 2)
        #expect(storedRoutes.contains { $0.id == route.id })
        #expect(storedRoutes.contains { $0.name == "Ride · Test trail" })
        fixture.viewModel.stop()
    }

    private func start(
        _ route: RideRoute,
        fixture: RideNavigationViewModelFixture
    ) async {
        fixture.viewModel.start()
        await fixture.deviceSpeedRepository.send(
            sample(coordinate(latitude: 41), seconds: 0, courseDegrees: 0)
        )
        #expect(await waitUntil { fixture.viewModel.viewState.savedRoutes.count == 1 })
        fixture.viewModel.openSavedRoute(id: route.id)
        fixture.viewModel.startPreviewedRoute()
        #expect(await waitUntil { fixture.viewModel.viewState.activity == .following })
    }

    private func makeRoute(finishLatitude: Double) -> RideRoute {
        let date = Date(timeIntervalSince1970: Constants.referenceTime)
        return RideRoute(
            name: "Test trail",
            createdAt: date,
            segments: [
                RideRouteSegment(points: [
                    RideRoutePoint(coordinate: coordinate(latitude: 41), timestamp: date),
                    RideRoutePoint(
                        coordinate: coordinate(latitude: finishLatitude),
                        timestamp: date.addingTimeInterval(60)
                    )
                ])
            ]
        )
    }

    private func sample(
        _ coordinate: GeographicCoordinate,
        seconds: TimeInterval,
        courseDegrees: Double
    ) -> DeviceSpeedSample {
        DeviceSpeedSample(
            kilometersPerHour: 20,
            accuracyMetersPerSecond: 1,
            courseDegrees: courseDegrees,
            courseAccuracyDegrees: 5,
            horizontalAccuracyMeters: 5,
            coordinate: coordinate,
            observedAt: Date(timeIntervalSince1970: Constants.referenceTime + seconds)
        )
    }

    private func coordinate(
        latitude: Double,
        longitude: Double = 2
    ) -> GeographicCoordinate {
        GeographicCoordinate(latitudeDegrees: latitude, longitudeDegrees: longitude)!
    }

    private func temporaryImportURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("gpx")
    }

    private enum Constants {
        static let referenceTime: TimeInterval = 1_700_000_000
    }
}
