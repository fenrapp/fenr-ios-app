import Foundation
import OfflineMapsData
import OfflineMapsDomain
import Testing
import TestSupport

@MainActor
struct OfflineMapsControllerTests {
    @Test func layersAndQueueRemainSerialWhenSatelliteFails() async throws {
        let fixture = OfflineMapsFixture()
        #expect(await fixture.start())
        try fixture.enqueue(satellite: true)
        try fixture.enqueue()
        #expect(await waitUntil { fixture.backend.calls.count == 1 })
        #expect(fixture.backend.calls[0].layer == .topographic)
        fixture.backend.complete(0)
        #expect(await waitUntil { fixture.backend.calls.count == 2 })
        #expect(fixture.controller.snapshot.regions[0].layers[0].available)
        fixture.backend.fail(1)
        #expect(await waitUntil { fixture.backend.calls.count == 3 })
        #expect(fixture.controller.snapshot.regions[0].status == .failed)
        #expect(fixture.controller.snapshot.regions[0].layers[0].available)
        #expect(!fixture.controller.snapshot.regions[0].layers[1].available)
        fixture.backend.complete(2)
        #expect(await waitUntil { fixture.controller.snapshot.regions[1].status == .ready })
        fixture.controller.setActive(false)
    }

    @Test func manualPauseSurvivesBackgroundAndLateCallback() async throws {
        let fixture = OfflineMapsFixture()
        #expect(await fixture.start())
        try fixture.enqueue()
        #expect(await waitUntil { fixture.backend.calls.count == 1 })
        let id = fixture.controller.snapshot.regions[0].id
        try await fixture.controller.perform(.pause(id))
        #expect(throws: CancellationError.self) {
            try fixture.backend.calls[0].progress(OfflineDownloadProgress(fraction: 0.9, bytes: 90))
        }
        fixture.controller.setActive(false)
        fixture.controller.setActive(true)
        #expect(fixture.controller.snapshot.regions[0].status == .paused)
        #expect(fixture.backend.calls.count == 1)
        try await fixture.controller.perform(.resume(id))
        #expect(await waitUntil { fixture.backend.calls.count == 2 })
        fixture.backend.complete(1)
        #expect(await waitUntil { fixture.controller.snapshot.regions[0].status == .ready })
        fixture.controller.setActive(false)
    }

    @Test func interruptedDownloadResumesOnlyOnAllowedNetwork() async throws {
        let fixture = OfflineMapsFixture()
        #expect(await fixture.start())
        try fixture.enqueue()
        #expect(await waitUntil { fixture.backend.calls.count == 1 })
        fixture.network.send(wifi: false)
        #expect(await waitUntil { fixture.controller.snapshot.regions[0].status == .waitingForWiFi })
        fixture.controller.setActive(false)
        fixture.controller.setActive(true)
        #expect(fixture.backend.calls.count == 1)
        fixture.network.send()
        #expect(await waitUntil { fixture.backend.calls.count == 2 })
        fixture.backend.complete(1)
        #expect(await waitUntil { fixture.controller.snapshot.regions[0].status == .ready })
        fixture.controller.setActive(false)
    }

    @Test func updateFailurePreservesPreviousResourceAndDeletePreservesOtherAreas() async throws {
        let fixture = OfflineMapsFixture()
        #expect(await fixture.start())
        try fixture.enqueue()
        #expect(await waitUntil { fixture.backend.calls.count == 1 })
        fixture.backend.complete(0)
        #expect(await waitUntil { fixture.controller.snapshot.regions[0].status == .ready })
        let original = fixture.controller.snapshot.regions[0]
        try await fixture.controller.perform(.update(original.id))
        #expect(await waitUntil { fixture.backend.calls.count == 2 })
        #expect(fixture.backend.calls[1].id != original.layers[0].resourceID)
        fixture.backend.fail(1, error: .providerLimit)
        #expect(await waitUntil { fixture.controller.snapshot.regions[0].status == .failed })
        #expect(fixture.controller.snapshot.regions[0].layers[0].available)
        #expect(fixture.controller.snapshot.regions[0].layers[0].resourceID == original.layers[0].resourceID)
        #expect(fixture.controller.snapshot.regions[0].failure == .providerLimit)
        try await fixture.controller.perform(.delete(original.id))
        #expect(fixture.controller.snapshot.regions.isEmpty)
        #expect(fixture.backend.deleted.contains(original.layers[0].resourceID))
        fixture.controller.setActive(false)
    }

    @Test func storageReserveRejectsDownloadsAndReconciliationRejectsMissingResources() async throws {
        let fixture = OfflineMapsFixture()
        #expect(await fixture.start())
        fixture.storage.free = 1_000_000_050
        #expect(throws: OfflineMapsFailure.insufficientStorage) { try fixture.enqueue() }
        #expect(fixture.controller.snapshot.regions.isEmpty)
        fixture.controller.setActive(false)
    }

    @Test func catalogFailureDoesNotEnqueueUnpersistedRegion() async throws {
        let fixture = OfflineMapsFixture()
        #expect(await fixture.start())
        fixture.storage.failsWrites = true
        #expect(throws: OfflineMapsFailure.catalog) { try fixture.enqueue() }
        #expect(fixture.controller.snapshot.regions.isEmpty)
        #expect(fixture.backend.calls.isEmpty)
        fixture.controller.setActive(false)
    }

    @Test func updateWhileDownloadingDoesNotStartConcurrentWork() async throws {
        let fixture = OfflineMapsFixture()
        #expect(await fixture.start())
        try fixture.enqueue()
        #expect(await waitUntil { fixture.backend.calls.count == 1 })
        let id = fixture.controller.snapshot.regions[0].id
        try await fixture.controller.perform(.update(id))
        #expect(fixture.backend.calls.count == 1)
        #expect(fixture.controller.snapshot.regions[0].status == .downloading)
        fixture.backend.complete(0)
        #expect(await waitUntil { fixture.controller.snapshot.regions[0].status == .ready })
        fixture.controller.setActive(false)
    }

    @Test func relaunchDoesNotTrustCatalogAvailability() async throws {
        let fixture = OfflineMapsFixture()
        let layer = OfflineLayerRecord(layer: .topographic, resourceID: "missing", available: true)
        var region = OfflineRegion(
            id: UUID(), name: "Synthetic",
            geometry: OfflineGeometryService().rectangle(west: 0, south: 0, east: 1, north: 1),
            routeID: nil, layers: [layer], now: Date()
        )
        region.status = .ready
        fixture.storage.catalog.regions = [region]
        #expect(await fixture.start())
        #expect(fixture.controller.snapshot.regions[0].status == .failed)
        #expect(!fixture.controller.snapshot.regions[0].layers[0].available)
        fixture.controller.setActive(false)
    }

    @Test func networkAvailabilityReflectsDownloadPolicyBeforeEnqueue() async throws {
        let fixture = OfflineMapsFixture()
        #expect(await fixture.start())
        #expect(fixture.controller.snapshot.isDownloadNetworkAllowed)
        fixture.network.send(wifi: false)
        #expect(await waitUntil { !fixture.controller.snapshot.isDownloadNetworkAllowed })
        try await fixture.controller.perform(.wifiOnly(false))
        #expect(fixture.controller.snapshot.isDownloadNetworkAllowed)
        fixture.network.send(connected: false, wifi: false)
        #expect(await waitUntil { !fixture.controller.snapshot.isDownloadNetworkAllowed })
        fixture.controller.setActive(false)
    }

}
