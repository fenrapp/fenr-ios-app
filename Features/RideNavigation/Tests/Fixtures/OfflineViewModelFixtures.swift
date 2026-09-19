import Foundation
import OfflineMapsDomain

enum OfflineViewModelFixtures {
    static func region(status: OfflineDownloadStatus = .ready) -> OfflineRegion {
        var region = OfflineRegion(
            id: UUID(), name: "Synthetic", geometry: OfflineGeometryService().rectangle(
                west: 0, south: 0, east: 1, north: 1
            ),
            routeID: nil,
            layers: [OfflineLayerRecord(layer: .topographic, resourceID: "synthetic", available: true)],
            now: Date(timeIntervalSince1970: 0)
        )
        region.status = status
        return region
    }
}
