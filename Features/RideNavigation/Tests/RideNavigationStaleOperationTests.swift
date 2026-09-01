import EnvironmentDomain
import Foundation
@testable import RideNavigation
import RideNavigationDomain
import SettingsDomain
import Testing
import TestSupport

@MainActor
struct RideNavigationStaleOperationTests {
    @Test("stop rejects late initial route and settings loads")
    func stopRejectsLateInitialRouteAndSettingsLoads() async {
        let repository = ControllableRecordedRouteRepository()
        let fixture = RideNavigationViewModelFixture(repository: repository)
        await repository.blockRouteLoads()
        await fixture.settingsRepository.blockLoads()

        fixture.viewModel.start()
        #expect(await waitUntil {
            let routeLoads = await repository.pendingLoadCount
            let settingsLoads = await fixture.settingsRepository.pendingLoadCount
            return routeLoads == 1 && settingsLoads == 1
        })
        fixture.viewModel.stop()

        await repository.resumeLoads(with: [route(name: "Late route")])
        await fixture.settingsRepository.resumeLoads(
            with: AppSettings(
                rideNavigation: RideNavigationSettings(preferredMapStyle: .satellite)
            )
        )
        #expect(await waitUntil {
            let routeLoads = await repository.pendingLoadCount
            let settingsLoads = await fixture.settingsRepository.pendingLoadCount
            return routeLoads == 0 && settingsLoads == 0
        })

        #expect(fixture.viewModel.viewState.savedRoutes.isEmpty)
        #expect(fixture.viewModel.viewState.mapScene.source == .appleStandard)
    }

    @Test("a newer external link ignores a canceled failure")
    func newerExternalLinkIgnoresCanceledFailure() async {
        let resolver = ControllableExternalMapLinkResolver()
        let fixture = RideNavigationViewModelFixture(externalMapLinkResolver: resolver)
        let firstURL = URL(string: "https://example.com/first")!
        let secondURL = URL(string: "https://example.com/second")!
        let secondDestination = place(name: "Second")
        fixture.viewModel.start()

        fixture.viewModel.openIncomingMapLink(firstURL)
        #expect(await waitUntil { await resolver.hasRequest(for: firstURL) })
        fixture.viewModel.openIncomingMapLink(secondURL)
        #expect(await waitUntil { await resolver.hasRequest(for: secondURL) })

        await resolver.succeed(url: secondURL, destination: secondDestination)
        #expect(await waitUntil {
            fixture.viewModel.viewState.errorText
                == "A current location is required to calculate this route."
        })
        await resolver.fail(url: firstURL)

        #expect(await waitUntil { !(await resolver.hasRequest(for: firstURL)) })
        #expect(
            fixture.viewModel.viewState.errorText
                == "A current location is required to calculate this route."
        )
        fixture.viewModel.stop()
    }

    @Test("a newer trail exit ignores a canceled failure")
    func newerTrailExitIgnoresCanceledFailure() async {
        let finder = ControllableTrailExitFinder()
        let route = route(name: "Trail")
        let fixture = RideNavigationViewModelFixture(routes: [route], trailExitFinder: finder)
        let origin = coordinate(latitude: 41, longitude: 2)
        fixture.viewModel.start()
        await fixture.deviceSpeedRepository.send(sample(at: origin))
        #expect(await waitUntil { fixture.viewModel.viewState.mapScene.userCoordinate != nil })
        #expect(await waitUntil { fixture.viewModel.viewState.savedRoutes.count == 1 })
        fixture.viewModel.openSavedRoute(id: route.id)
        fixture.viewModel.startPreviewedRoute()
        #expect(await waitUntil { fixture.viewModel.viewState.activity == .following })

        fixture.viewModel.findTrailExit()
        #expect(await waitUntil { await finder.requestCount == 1 })
        fixture.viewModel.findTrailExit()
        #expect(await waitUntil { await finder.requestCount == 2 })
        await finder.fail(request: 0)
        await finder.succeed(request: 0, exit: trailExit(from: origin))

        #expect(await waitUntil {
            fixture.viewModel.viewState.trailExitPreview?.title == "Exit"
        })
        #expect(fixture.viewModel.viewState.errorText == nil)
        fixture.viewModel.stop()
    }

    @Test("a newer road calculation ignores a canceled failure")
    func newerRoadCalculationIgnoresCanceledFailure() async {
        let fixture = RideNavigationViewModelFixture()
        let origin = coordinate(latitude: 41, longitude: 2)
        let first = place(name: "First")
        let second = place(name: "Second")
        fixture.viewModel.start()

        fixture.viewModel.calculateRoadPreview(from: origin, to: first, showsSearchLoading: false)
        #expect(await waitUntil { await fixture.roadRouteCalculator.requestCount == 1 })
        fixture.viewModel.calculateRoadPreview(from: origin, to: second, showsSearchLoading: false)
        #expect(await waitUntil { await fixture.roadRouteCalculator.requestCount == 2 })

        await fixture.roadRouteCalculator.fail(request: 0)
        await fixture.roadRouteCalculator.succeed(
            request: 0,
            routes: [roadRoute(name: "Second route", from: origin, to: second.coordinate)]
        )

        #expect(await waitUntil {
            fixture.viewModel.viewState.roadRouteOptions.first?.title == "Recommended"
        })
        #expect(fixture.viewModel.viewState.errorText == nil)
        fixture.viewModel.stop()
    }

    @Test("a completed route save is serialized and can be retried")
    func completedRouteSaveSerializesAndRetries() async {
        let repository = ControllableRecordedRouteRepository()
        let fixture = RideNavigationViewModelFixture(repository: repository)
        fixture.viewModel.start()
        fixture.viewModel.completedRecording = route(name: "Original")

        fixture.viewModel.saveCompletedRoute(name: "First")
        #expect(await waitUntil { await repository.saveRequestCount == 1 })
        fixture.viewModel.saveCompletedRoute(name: "Latest")
        #expect(await repository.saveRequestCount == 1)

        await repository.failSave(request: 0)
        #expect(await waitUntil {
            if case .failed = fixture.viewModel.viewState.routePersistence { return true }
            return false
        })
        fixture.viewModel.retryCompletedRouteSave(name: "Latest")
        #expect(await waitUntil { await repository.saveRequestCount == 1 })
        await repository.succeedSave(request: 0)

        #expect(await waitUntil { fixture.viewModel.viewState.routePersistence == .saved })
        #expect(fixture.viewModel.viewState.savedRoutes.first?.title == "Latest")
        #expect(fixture.viewModel.viewState.errorText == nil)
        fixture.viewModel.stop()
    }

    @Test("stop cancels draft persistence and guidance before restart")
    func stopCancelsDraftPersistenceAndGuidanceBeforeRestart() async {
        let repository = ControllableRecordedRouteRepository()
        let timing = ControllableRideNavigationTiming()
        let fixture = RideNavigationViewModelFixture(
            repository: repository,
            timing: timing.makeTiming()
        )
        fixture.viewModel.start()
        fixture.viewModel.startRecording()
        await fixture.deviceSpeedRepository.send(sample(at: coordinate(latitude: 41, longitude: 2)))
        #expect(await waitUntil {
            fixture.viewModel.viewState.mapScene.polylines.contains { $0.role == .recorded }
        })
        #expect(await waitUntil {
            let requested = await timing.requestedSleepCount(for: .seconds(2))
            let pending = await timing.pendingSleepCount(for: .seconds(2))
            return requested == 1 && pending == 1
        })
        fixture.viewModel.toggleRecordingPause()
        #expect(await waitUntil {
            let requested = await timing.requestedSleepCount(for: .seconds(2))
            let pending = await timing.pendingSleepCount(for: .seconds(2))
            return requested == 2 && pending == 1
        })

        fixture.viewModel.stop()
        #expect(await waitUntil {
            let draftSleeps = await timing.pendingSleepCount(for: .seconds(2))
            let guidanceSleeps = await timing.pendingSleepCount(for: .seconds(1))
            let allSleeps = await timing.pendingSleepCount()
            return draftSleeps == 0 && guidanceSleeps == 0 && allSleeps == 0
        })
        #expect(await waitUntil { await repository.draftSaveCount == 0 })

        fixture.viewModel.start()
        #expect(await waitUntil { await fixture.deviceSpeedRepository.activeObserverCount() == 1 })
        #expect(fixture.viewModel.viewState.errorText == nil)
        fixture.viewModel.stop()
        #expect(await waitUntil { await timing.pendingSleepCount() == 0 })
    }

    @Test("voice and feedback operations do not cancel each other")
    func voiceAndFeedbackHaveIndependentOwnership() async {
        let fixture = RideNavigationViewModelFixture()

        fixture.viewModel.announce("Keep right")
        fixture.viewModel.replaceFeedbackTask { [guidance = fixture.guidance] in
            await guidance.notifySuccess()
        }

        #expect(await waitUntil {
            let announcements = await fixture.guidance.recordedAnnouncements()
            let successes = await fixture.guidance.recordedSuccessCount()
            return announcements == ["Keep right"] && successes == 1
        })
    }

    private func route(name: String) -> RideRoute {
        let start = coordinate(latitude: 41, longitude: 2)
        let finish = coordinate(latitude: 41.001, longitude: 2.001)
        return RideRoute(
            name: name,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            segments: [
                RideRouteSegment(points: [
                    RideRoutePoint(coordinate: start),
                    RideRoutePoint(coordinate: finish)
                ])
            ]
        )
    }

    private func place(name: String) -> NavigationPlace {
        NavigationPlace(
            name: name,
            detail: "Test destination",
            coordinate: coordinate(latitude: 41.01, longitude: 2.01)
        )
    }

    private func roadRoute(
        name: String,
        from origin: GeographicCoordinate,
        to destination: GeographicCoordinate
    ) -> RoadNavigationRoute {
        RoadNavigationRoute(
            name: name,
            points: [origin, destination],
            distanceMeters: 1_000,
            expectedTravelTime: 120,
            steps: []
        )
    }

    private func trailExit(from origin: GeographicCoordinate) -> TrailExitRoute {
        let destination = place(name: "Exit")
        return TrailExitRoute(
            destination: destination,
            route: roadRoute(name: "Exit route", from: origin, to: destination.coordinate)
        )
    }

    private func sample(at coordinate: GeographicCoordinate) -> DeviceSpeedSample {
        DeviceSpeedSample(
            kilometersPerHour: 12,
            accuracyMetersPerSecond: 1,
            courseDegrees: 0,
            courseAccuracyDegrees: 5,
            horizontalAccuracyMeters: 5,
            coordinate: coordinate,
            observedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    private func coordinate(latitude: Double, longitude: Double) -> GeographicCoordinate {
        GeographicCoordinate(latitudeDegrees: latitude, longitudeDegrees: longitude)!
    }
}
