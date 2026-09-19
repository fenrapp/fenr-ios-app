import Foundation
import OfflineMapsDomain
@testable import RideNavigation
import Testing
import TestSupport

@MainActor
struct OfflineRouteSelectionTests {
    @Test("Route downloads keep route geometry and framing when the rider is elsewhere")
    func routeSelectionIgnoresAutomaticLocationUpdates() async {
        let repository = OfflineMapsRepositorySpy()
        let position = TestDeviceSpeedRepository()
        let seed = OfflineViewModelFixtures.routeSeed
        let model = OfflineViewModelTestFactory.selection(repository, seed: seed, position: position)
        #expect(model.scene.center == OfflineViewModelFixtures.routeStart)
        model.start()
        #expect(await waitUntil { repository.estimates.count == 1 })
        repository.completeEstimate(0)
        #expect(await waitUntil { model.canDownload })
        let outlines = model.scene.outlines
        #expect(!outlines.isEmpty)
        #expect(model.scene.isCorridor)

        #expect(await waitUntil { await position.activeObserverCount() == 1 })
        await position.send(OfflineViewModelFixtures.positionSample)
        let didLocate = await waitUntil {
            #expect(model.scene.center == OfflineViewModelFixtures.routeStart)
            model.locate()
            return model.scene.center == OfflineViewModelFixtures.distantLocation
        }
        #expect(didLocate)
        let cameraCommand = model.scene.cameraCommand
        model.setMargin(5)
        #expect(model.scene.center == OfflineViewModelFixtures.routeStart)
        #expect(model.scene.cameraCommand == cameraCommand)
        #expect(await waitUntil { repository.estimates.count == 2 })
        let request = repository.estimates[1]
        #expect(request.routeID == seed.routeID)
        let geometry = OfflineGeometryService()
        #expect(geometry.contains(OfflineCoordinate(latitude: 41, longitude: 2), in: request.geometry))
        #expect(!geometry.contains(OfflineCoordinate(latitude: 48, longitude: 10), in: request.geometry))
        repository.completeEstimate(1)
        model.stop()
        #expect(await waitUntil { await position.activeObserverCount() == 0 })
    }

    @Test("Area selection still uses the current position when no route or center was supplied")
    func unseededAreaUsesLocation() async {
        let repository = OfflineMapsRepositorySpy()
        let position = TestDeviceSpeedRepository()
        let model = OfflineViewModelTestFactory.selection(repository, position: position)
        #expect(model.scene.center == nil)
        model.start()
        await position.send(OfflineViewModelFixtures.positionSample)
        #expect(await waitUntil { model.scene.center == OfflineViewModelFixtures.distantLocation })
        #expect(!model.scene.isCorridor)
        #expect(model.scene.cameraCommand == 0)
        model.stop()
    }

    @Test("The library opens the supplied route selection on its first presentation")
    func libraryOpensRouteSeed() {
        let model = OfflineViewModelTestFactory.library(OfflineMapsRepositorySpy())
        let seed = OfflineViewModelFixtures.routeSeed
        model.start(routeID: nil, seed: seed)
        #expect(model.selection == seed)
        model.stop()
    }

    @Test("An unsaved imported route passes every segment to offline selection")
    func importedRouteProvidesOfflineGeometry() async throws {
        let route = OfflineViewModelFixtures.importedRoute
        let fixture = RideNavigationViewModelFixture(importer: FixedGPXRouteImporter(routes: [route]))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".gpx")
        try Data("test".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url); fixture.viewModel.stop() }
        fixture.viewModel.start()
        await fixture.deviceSpeedRepository.send(OfflineViewModelFixtures.positionSample)
        #expect(await waitUntil { fixture.viewModel.viewState.mapScene.userCoordinate != nil })
        fixture.viewModel.importGPX(from: url)
        let seed = try #require(fixture.viewModel.offlineSelectionSeed)
        #expect(seed.routeID == route.id)
        #expect(seed.segments == [[OfflineViewModelFixtures.routeStart], [OfflineViewModelFixtures.routeEnd]])
        #expect(seed.initialCenter == OfflineViewModelFixtures.routeStart)
        #expect(seed.center == nil)
    }
}
