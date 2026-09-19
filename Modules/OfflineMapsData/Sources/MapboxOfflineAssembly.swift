import Foundation
import MapboxMaps
import OfflineMapsDomain

@MainActor
public enum MapboxOfflineAssembly {
    public static func make(directory: URL) -> OfflineMapsController {
        let fileManager = FileManager()
        let storage = OfflineCatalogStorage(directory: directory, fileManager: fileManager)
        _ = try? storage.status()
        MapboxMapsOptions.dataPath = directory.appendingPathComponent("styles", isDirectory: true)
        let tileStore = TileStore.shared(for: directory.appendingPathComponent("tiles", isDirectory: true))
        MapboxMapsOptions.tileStore = tileStore
        MapboxMapsOptions.tileStoreUsageMode = .readOnly
        let offlineManager = OfflineManager()
        return OfflineMapsController(
            backend: MapboxOfflineBackend(tileStore: tileStore, offlineManager: offlineManager),
            storage: storage, network: OfflineNetworkMonitor(), now: Date.init
        )
    }
}
