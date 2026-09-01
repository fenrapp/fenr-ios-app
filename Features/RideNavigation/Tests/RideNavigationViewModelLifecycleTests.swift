import EnvironmentDomain
import Foundation
@testable import RideNavigation
import RideNavigationDomain
import Testing
import TestSupport

@MainActor
struct RideNavigationViewModelLifecycleTests {
    @Test("mini mode keeps location and suspends motorcycle observation")
    func miniModeUsesOnlyRequiredObservations() async {
        let fixture = RideNavigationViewModelFixture()

        fixture.viewModel.start()
        #expect(await waitUntil {
            let vehicleCount = await fixture.vehicleSession.activeObserverCount()
            let locationCount = await fixture.deviceSpeedRepository.activeObserverCount()
            return vehicleCount == 1 && locationCount == 1
        })

        fixture.viewModel.setPresentationMode(.mini)
        #expect(await waitUntil {
            let vehicleCount = await fixture.vehicleSession.activeObserverCount()
            let locationCount = await fixture.deviceSpeedRepository.activeObserverCount()
            return vehicleCount == 0 && locationCount == 1
        })

        fixture.viewModel.setPresentationMode(.fullScreen)
        #expect(await waitUntil {
            let vehicleCount = await fixture.vehicleSession.activeObserverCount()
            let locationCount = await fixture.deviceSpeedRepository.activeObserverCount()
            return vehicleCount == 1 && locationCount == 1
        })

        fixture.viewModel.stop()
        #expect(await waitUntil {
            let vehicleCount = await fixture.vehicleSession.activeObserverCount()
            let locationCount = await fixture.deviceSpeedRepository.activeObserverCount()
            return vehicleCount == 0 && locationCount == 0
        })
    }

    @Test("recording continues to append its breadcrumb in mini mode")
    func miniRecordingContinues() async {
        let fixture = RideNavigationViewModelFixture()
        let first = coordinate()
        let second = coordinate(offset: 0.0002)
        fixture.viewModel.start()
        fixture.viewModel.startRecording()
        #expect(fixture.viewModel.canMinimize)
        fixture.viewModel.setPresentationMode(.mini)

        await fixture.deviceSpeedRepository.send(sample(at: first, seconds: 0))
        await fixture.deviceSpeedRepository.send(sample(at: second, seconds: 5))

        #expect(await waitUntil {
            fixture.viewModel.miniViewState.mapScene.polylines.contains {
                $0.role == .recorded && $0.points.count == 2
            }
        })
        #expect(fixture.viewModel.miniViewState.statusText == nil)
        fixture.viewModel.stop()
    }

    @Test("a stale search failure cannot replace newer results")
    func staleSearchFailureIsIgnored() async throws {
        let fixture = RideNavigationViewModelFixture()
        let destination = NavigationPlace(
            name: "Fresh destination",
            detail: "Barcelona",
            coordinate: coordinate(offset: 0.01)
        )

        fixture.viewModel.updateSearchQuery("First query")
        #expect(await waitUntil { await fixture.placeSearch.hasRequest(for: "First query") })

        fixture.viewModel.updateSearchQuery("Second query")
        #expect(await waitUntil { await fixture.placeSearch.hasRequest(for: "Second query") })
        await fixture.placeSearch.succeed(query: "Second query", places: [destination])
        #expect(await waitUntil {
            fixture.viewModel.viewState.searchResults.first?.title == destination.name
        })

        await fixture.placeSearch.fail(query: "First query")
        #expect(await waitUntil {
            await fixture.placeSearch.hasCompletedRequest(for: "First query")
        })

        #expect(fixture.viewModel.viewState.errorText == nil)
        #expect(fixture.viewModel.viewState.searchResults.first?.title == destination.name)
    }

    @Test("a canceled route calculation cannot publish partial alternatives")
    func canceledRouteCalculationDoesNotMutateState() async throws {
        let fixture = RideNavigationViewModelFixture()
        let origin = coordinate()
        let destination = NavigationPlace(
            name: "Destination",
            detail: "Barcelona",
            coordinate: coordinate(offset: 0.01)
        )
        let route = RoadNavigationRoute(
            name: "Calculated route",
            points: [origin, destination.coordinate],
            distanceMeters: 1_000,
            expectedTravelTime: 120,
            steps: []
        )

        fixture.viewModel.start()
        await fixture.deviceSpeedRepository.send(
            DeviceSpeedSample(
                kilometersPerHour: 12,
                accuracyMetersPerSecond: 1,
                horizontalAccuracyMeters: 5,
                coordinate: origin,
                observedAt: .now
            )
        )
        fixture.viewModel.updateSearchQuery("Destination")
        #expect(await waitUntil { await fixture.placeSearch.hasRequest(for: "Destination") })
        await fixture.placeSearch.succeed(query: "Destination", places: [destination])
        #expect(await waitUntil { fixture.viewModel.viewState.searchResults.count == 1 })

        fixture.viewModel.selectSearchResult(id: destination.id)
        #expect(await waitUntil { await fixture.roadRouteCalculator.hasPendingRequest })
        fixture.viewModel.stop()
        await fixture.roadRouteCalculator.succeed(routes: [route])
        #expect(await waitUntil { await fixture.roadRouteCalculator.completionCount == 1 })

        fixture.viewModel.start()
        fixture.viewModel.setMapStyle(MapSourceDescriptor.appleHybrid.id)

        #expect(fixture.viewModel.viewState.roadRouteOptions.isEmpty)
        #expect(fixture.viewModel.viewState.screen == .home)
        fixture.viewModel.stop()
    }

    @Test("saving and closing a recording summary refreshes the home library")
    func savingAndClosingRecordingSummaryRefreshesSavedRoutes() async {
        let repository = ControllableRecordedRouteRepository()
        let fixture = RideNavigationViewModelFixture(repository: repository)
        let first = coordinate()
        let second = coordinate(offset: 0.0002)
        fixture.viewModel.start()
        fixture.viewModel.startRecording()
        await fixture.deviceSpeedRepository.send(sample(at: first, seconds: 0))
        await fixture.deviceSpeedRepository.send(sample(at: second, seconds: 5))
        #expect(await waitUntil { fixture.viewModel.viewState.distanceText != "0 ft" })
        fixture.viewModel.finishActivity()

        fixture.viewModel.saveCompletedRouteAndClose(name: "Saved recording")
        #expect(await waitUntil { await repository.hasPendingSave })

        #expect(fixture.viewModel.viewState.screen == .summary)
        #expect(fixture.viewModel.viewState.routePersistence == .saving)

        await repository.completeSave()

        #expect(await waitUntil { await repository.saveWasCancelled != nil })
        #expect(await repository.saveWasCancelled == false)
        #expect(await waitUntil {
            fixture.viewModel.viewState.screen == .home
                && fixture.viewModel.viewState.savedRoutes.map(\.title) == ["Saved recording"]
        })
        fixture.viewModel.stop()
    }

    @Test("a saved route can be shared as a named GPX file")
    func savedRouteCanBeShared() async {
        let route = savedRoute(name: "Mountain Loop")
        let fixture = RideNavigationViewModelFixture(routes: [route])
        fixture.viewModel.start()
        #expect(await waitUntil { fixture.viewModel.viewState.savedRoutes.count == 1 })
        #expect(fixture.viewModel.viewState.savedRoutes.first?.detail.contains("2023") == true)

        fixture.viewModel.shareSavedRoute(id: route.id)

        #expect(fixture.viewModel.shareRequest?.filename == "Mountain-Loop.gpx")
        #expect(fixture.viewModel.shareRequest?.data == StubGPXRouteExporter.exportedData)
        fixture.viewModel.clearShareRequest()
        #expect(fixture.viewModel.shareRequest == nil)
        fixture.viewModel.stop()
    }

    @Test("deleting a saved route updates presentation and persistence")
    func savedRouteCanBeDeleted() async {
        let route = savedRoute(name: "Route to delete")
        let repository = StubRecordedRouteRepository(routes: [route])
        let fixture = RideNavigationViewModelFixture(repository: repository)
        fixture.viewModel.start()
        #expect(await waitUntil { fixture.viewModel.viewState.savedRoutes.count == 1 })

        fixture.viewModel.deleteSavedRoute(id: route.id)

        #expect(fixture.viewModel.viewState.savedRoutes.isEmpty)
        #expect(await waitUntil { await repository.loadRoutes().isEmpty })
        fixture.viewModel.stop()
    }

    private func coordinate(offset: Double = .zero) -> GeographicCoordinate {
        GeographicCoordinate(latitudeDegrees: 41 + offset, longitudeDegrees: 2 + offset)!
    }

    private func sample(at coordinate: GeographicCoordinate, seconds: TimeInterval) -> DeviceSpeedSample {
        DeviceSpeedSample(
            kilometersPerHour: 12,
            accuracyMetersPerSecond: 1,
            courseDegrees: 45,
            courseAccuracyDegrees: 5,
            horizontalAccuracyMeters: 5,
            coordinate: coordinate,
            observedAt: Date(timeIntervalSince1970: 1_700_000_000 + seconds)
        )
    }

    private func savedRoute(name: String) -> RideRoute {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        return RideRoute(
            name: name,
            createdAt: date,
            segments: [
                RideRouteSegment(points: [
                    RideRoutePoint(coordinate: coordinate(), timestamp: date),
                    RideRoutePoint(coordinate: coordinate(offset: 0.001), timestamp: date)
                ])
            ]
        )
    }
}
