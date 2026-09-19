import Foundation
import OfflineMapsDomain
@testable import RideNavigation
import Testing

struct OfflineNavigationMapperTests {
    @Test(arguments: [29, 30, 31])
    func reminderSuggestsUpdatesWithoutExpiringDownloadedLayers(daysSinceUpdate: Int) {
        let updatedAt = Date(timeIntervalSince1970: 0)
        var region = OfflineViewModelFixtures.region()
        region.layers[0].updatedAt = updatedAt
        let now = updatedAt.addingTimeInterval(TimeInterval(daysSinceUpdate * 24 * 60 * 60))

        let area = OfflineMapsPresentationMapper().area(region, now: now)

        #expect((area.reminder != nil) == (daysSinceUpdate > 30))
        #expect(area.canUpdate)
        #expect(area.layerRows[0].detail == String(localized: .offlineLayerAvailable))
        #expect(!area.canResume)
    }

    @Test func unavailableSatelliteFallsBackWithoutChangingSavedPreference() {
        let geometry = OfflineGeometryService()
        let mapper = OfflineNavigationMapper(geometry: geometry)
        let region = OfflineRegion(
            id: UUID(), name: "Synthetic", geometry: geometry.rectangle(west: 0, south: 0, east: 2, north: 2),
            routeID: nil, layers: [OfflineLayerRecord(layer: .topographic, resourceID: "topo", available: true)],
            now: Date()
        )
        let snapshot = OfflineMapsSnapshot(
            regions: [region], usedBytes: 100, freeBytes: 2_000_000_000,
            wifiOnly: true, isConnected: true, isReconciled: true, failure: nil
        )
        let result = mapper.presentation(
            source: .appleHybrid, coordinate: NavigationMapCoordinate(latitudeDegrees: 1, longitudeDegrees: 1),
            snapshot: snapshot
        )
        #expect(result.source == .appleStandard)
        #expect(result.notice != nil)
        let outside = mapper.presentation(
            source: .appleHybrid, coordinate: NavigationMapCoordinate(latitudeDegrees: 3, longitudeDegrees: 3),
            snapshot: snapshot
        )
        #expect(outside.source == .appleHybrid)
        #expect(outside.notice != result.notice)
    }

    @Test func disconnectedCoverageNeverMarksRouteAsComplete() {
        let geometry = OfflineGeometryService()
        let mapper = OfflineNavigationMapper(geometry: geometry)
        let request = geometry.rectangle(west: 0, south: 0, east: 2, north: 2)
        let regions = [
            geometry.rectangle(west: 0, south: 0, east: 0.9, north: 2),
            geometry.rectangle(west: 1.1, south: 0, east: 2, north: 2)
        ].map {
            OfflineRegion(
                id: UUID(), name: "Synthetic", geometry: $0, routeID: nil,
                layers: [OfflineLayerRecord(layer: .topographic, resourceID: UUID().uuidString, available: true)],
                now: Date()
            )
        }
        let snapshot = OfflineMapsSnapshot(
            regions: regions, usedBytes: 100, freeBytes: 2_000_000_000,
            wifiOnly: true, isConnected: false, isReconciled: true, failure: nil
        )
        #expect(mapper.routeStatus(request, snapshot: snapshot) == String(localized: .offlineRoutePartial))
    }

    @Test func queuedUpdateExplainsNetworkWaitAndPreservesLayerAvailability() {
        let mapper = OfflineMapsPresentationMapper()
        let now = Date()
        var region = OfflineRegion(
            id: UUID(), name: "Synthetic", geometry: OfflineGeometry(rectangles: []), routeID: nil,
            layers: [
                OfflineLayerRecord(layer: .topographic, resourceID: "topo", available: true, updatedAt: now),
                OfflineLayerRecord(layer: .satellite, resourceID: "satellite")
            ], now: now
        )
        region.isUpdating = true
        let waiting = mapper.area(region, now: now, networkAllowed: false)
        #expect(waiting.status == String(localized: .offlineWaitingForNetwork))
        #expect(waiting.explanation == String(localized: .offlineWaitingExplanation))
        #expect(waiting.layerRows[0].detail == String(localized: .offlineLayerAvailable))
        #expect(waiting.layerRows[1].detail == String(localized: .offlineLayerPending))
        #expect(waiting.canPause && !waiting.canUpdate)
        region.status = .downloading
        region.progress = 0.5
        let downloading = mapper.area(region, now: now)
        #expect(downloading.explanation == String(localized: .offlineUpdatingExplanation))
        #expect(downloading.progress == 0.5)
        region.status = .ready
        region.isUpdating = false
        let ready = mapper.area(region, now: now)
        #expect(ready.canUpdate && !ready.canPause && !ready.canResume)
        #expect(ready.progress == nil)
    }

}
