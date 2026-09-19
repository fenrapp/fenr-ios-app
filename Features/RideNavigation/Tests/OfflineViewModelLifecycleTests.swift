import Foundation
import OfflineMapsDomain
@testable import RideNavigation
import Testing
import TestSupport

@MainActor
struct OfflineViewModelLifecycleTests {
    @Test func librarySerializesActionsAndIgnoresDuplicateAreaOperations() async {
        let repository = OfflineMapsRepositorySpy()
        let area = OfflineViewModelFixtures.region()
        repository.regions = [area]
        repository.suspendsCommands = true
        let model = OfflineViewModelTestFactory.library(repository)
        model.update(area.id)
        #expect(await waitUntil { repository.commands.count == 1 })
        model.delete(area.id)
        model.setWiFiOnly(false)
        #expect(model.busyAreaIDs == [area.id])
        repository.completeCommand(0)
        #expect(await waitUntil { repository.commands.count == 2 })
        if case .wifiOnly(false) = repository.commands.last {} else { Issue.record("Expected queued Wi-Fi policy") }
        repository.completeCommand(1)
        #expect(await waitUntil { model.busyAreaIDs.isEmpty })
        model.stop()
    }

    @Test func libraryOnlyUpdatesReadyAreasAndDeletesKnownAreas() async {
        let repository = OfflineMapsRepositorySpy()
        let area = OfflineViewModelFixtures.region(status: .queued)
        repository.regions = [area]
        let model = OfflineViewModelTestFactory.library(repository)
        model.update(area.id)
        model.delete(UUID())
        model.delete(area.id)
        #expect(await waitUntil { repository.commands.count == 1 })
        if case .delete(area.id) = repository.commands[0] {} else { Issue.record("Expected delete") }
        model.stop()
    }

    @Test func libraryStopDiscardsLateFailureAndQueuedCommands() async {
        let repository = OfflineMapsRepositorySpy()
        let area = OfflineViewModelFixtures.region()
        repository.regions = [area]
        repository.suspendsCommands = true
        let model = OfflineViewModelTestFactory.library(repository)
        model.update(area.id)
        #expect(await waitUntil { repository.commands.count == 1 })
        model.setWiFiOnly(false)
        model.stop()
        model.start(routeID: nil, seed: nil)
        model.delete(area.id)
        #expect(await waitUntil { repository.commands.count == 2 })
        repository.completeCommand(0, failure: .provider)
        repository.completeCommand(1)
        #expect(await waitUntil { model.busyAreaIDs.isEmpty })
        #expect(model.errorText == nil)
        #expect(repository.commands.count == 2)
        model.stop()
    }

    @Test func detailCanRestartWithoutLateOperationChangingNewState() async {
        let repository = OfflineMapsRepositorySpy()
        let area = OfflineViewModelFixtures.region()
        repository.regions = [area]
        repository.suspendsCommands = true
        let model = OfflineViewModelTestFactory.detail(repository, id: area.id)
        model.start()
        model.delete()
        #expect(await waitUntil { repository.commands.count == 1 })
        model.stop()
        #expect(!model.isBusy)
        model.start()
        model.update()
        #expect(await waitUntil { repository.commands.count == 2 })
        repository.completeCommand(0, failure: .provider)
        #expect(!model.didDelete)
        #expect(model.isBusy)
        repository.completeCommand(1)
        #expect(await waitUntil { !model.isBusy })
        #expect(!model.didDelete)
        #expect(model.errorText == nil)
        model.stop()
    }

    @Test func selectionRestartsInterruptedEstimateForUnchangedViewport() async {
        let repository = OfflineMapsRepositorySpy()
        let model = OfflineViewModelTestFactory.selection(repository)
        model.start()
        model.setViewport(OfflineMapViewport(west: 0, south: 0, east: 1, north: 1))
        #expect(await waitUntil { repository.estimates.count == 1 })
        model.stop()
        #expect(!model.isEstimating)
        #expect(!model.canDownload)
        model.start()
        #expect(await waitUntil { repository.estimates.count == 2 })
        repository.completeEstimate(1)
        #expect(await waitUntil { model.canDownload })
        let currentText = model.estimateText
        repository.completeEstimate(0, storageBytes: 9_500_000_000)
        model.setSatellite(true)
        #expect(await waitUntil { repository.estimates.count == 3 })
        #expect(model.estimateText == currentText)
        repository.completeEstimate(2)
        #expect(await waitUntil { model.canDownload && !model.isEstimating })
        model.stop()
    }
}
