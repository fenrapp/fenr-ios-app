import CoreLocation
import Foundation
import MapboxMaps
import OfflineMapsDomain

@MainActor
public final class MapboxOfflineBackend: OfflineMapsBackend {
    private let tileStore: TileStore
    private let offlineManager: OfflineManager

    public init(tileStore: TileStore, offlineManager: OfflineManager) {
        self.tileStore = tileStore
        self.offlineManager = offlineManager
    }

    public func setStorageLimit(_ bytes: UInt64) {
        tileStore.setOptionForKey(TileStoreOptions.diskQuota, value: NSNumber(value: bytes))
    }

    public func estimate(geometry: OfflineGeometry, layer: OfflineLayer) async throws -> OfflineMapEstimate {
        let options = try loadOptions(geometry: geometry, layer: layer, wifiOnly: false)
        let result = try await MapboxAsyncOperation<TileRegionEstimateResult>.run { completion in
            tileStore.estimateTileRegion(
                forId: "estimate-" + UUID().uuidString, loadOptions: options,
                progress: { _ in }, completion: completion
            )
        }
        return OfflineMapEstimate(transferBytes: result.transferSize, storageBytes: result.storageSize)
    }

    public func download(
        resourceID: String, geometry: OfflineGeometry, layer: OfflineLayer, wifiOnly: Bool,
        progress: @escaping @MainActor (OfflineDownloadProgress) throws -> Void
    ) async throws {
        guard let styleOptions = StylePackLoadOptions(
            glyphsRasterizationMode: .ideographsRasterizedLocally,
            metadata: ["application": "FENR"], acceptExpired: false
        ) else { throw OfflineMapsFailure.configuration }
        _ = try await MapboxAsyncOperation<StylePack>.run { completion in
            offlineManager.loadStylePack(
                for: style(layer), loadOptions: styleOptions, progress: { _ in }, completion: completion
            )
        }
        try Task.checkCancellation()
        let options = try loadOptions(geometry: geometry, layer: layer, wifiOnly: wifiOnly)
        let cancellation = MapboxAsyncOperation<Void>()
        defer { cancellation.cancel() }
        typealias ProgressStream = AsyncThrowingStream<OfflineDownloadProgress, Error>
        let stream = ProgressStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let operation = tileStore.loadTileRegion(forId: resourceID, loadOptions: options) { value in
                continuation.yield(OfflineDownloadProgress(
                    fraction: Double(value.completedResourceCount) / Double(max(1, value.requiredResourceCount)),
                    bytes: value.completedResourceSize
                ))
            } completion: { result in
                switch result {
                case .success(let region):
                    if region.requiredResourceCount > 0,
                       region.completedResourceCount == region.requiredResourceCount {
                        continuation.yield(OfflineDownloadProgress(fraction: 1, bytes: region.completedResourceSize))
                        continuation.finish()
                    } else {
                        continuation.finish(throwing: OfflineMapsFailure.provider)
                    }
                case .failure(let error):
                    if case .tileCountExceeded = error as? TileRegionError {
                        continuation.finish(throwing: OfflineMapsFailure.providerLimit)
                    } else if case .diskFull = error as? TileRegionError {
                        continuation.finish(throwing: OfflineMapsFailure.insufficientStorage)
                    } else {
                        continuation.finish(throwing: error)
                    }
                }
            }
            cancellation.install(operation)
            continuation.onTermination = { _ in cancellation.cancel() }
        }
        for try await value in stream {
            try Task.checkCancellation()
            try progress(value)
        }
        try Task.checkCancellation()
    }

    public func availableResources() async throws -> Set<String> {
        let styles = try await MapboxAsyncOperation<[StylePack]>.run { completion in
            offlineManager.allStylePacks(completion: completion)
            return nil
        }
        let regions = try await MapboxAsyncOperation<[TileRegion]>.run { completion in
            tileStore.allTileRegions(completion: completion)
            return nil
        }
        let availableStyles = Set(styles.map { $0.styleURI })
        return Set(regions.filter { region in
            let layer: OfflineLayer = region.id.contains("satellite") ? .satellite : .topographic
            return availableStyles.contains(style(layer).rawValue)
                && region.requiredResourceCount > 0 && region.completedResourceCount == region.requiredResourceCount
        }.map(\.id))
    }

    public func delete(resourceID: String) async throws {
        let regions = try await MapboxAsyncOperation<[TileRegion]>.run { completion in
            tileStore.allTileRegions(completion: completion)
            return nil
        }
        guard regions.contains(where: { $0.id == resourceID }) else { return }
        _ = try await MapboxAsyncOperation<TileRegion>.run { completion in
            tileStore.removeRegion(forId: resourceID, completion: completion)
            return nil
        }
    }

    private func style(_ layer: OfflineLayer) -> StyleURI {
        layer == .topographic ? StyleURI(rawValue: "mapbox://styles/mapbox/outdoors-v12")! : .satelliteStreets
    }

    private func loadOptions(
        geometry: OfflineGeometry, layer: OfflineLayer, wifiOnly: Bool
    ) throws -> TileRegionLoadOptions {
        guard geometry.isValid else { throw OfflineMapsFailure.invalidSelection }
        let polygons = geometry.rectangles.map { bounds in
            Polygon([[
                CLLocationCoordinate2D(latitude: bounds.south, longitude: bounds.west),
                CLLocationCoordinate2D(latitude: bounds.south, longitude: bounds.east),
                CLLocationCoordinate2D(latitude: bounds.north, longitude: bounds.east),
                CLLocationCoordinate2D(latitude: bounds.north, longitude: bounds.west),
                CLLocationCoordinate2D(latitude: bounds.south, longitude: bounds.west)
            ]])
        }
        let descriptor = offlineManager.createTilesetDescriptor(
            for: TilesetDescriptorOptions(styleURI: style(layer), zoomRange: 0...16, tilesets: nil)
        )
        guard let options = TileRegionLoadOptions(
            geometry: .multiPolygon(MultiPolygon(polygons)), descriptors: [descriptor],
            acceptExpired: false, networkRestriction: wifiOnly ? .disallowExpensive : .none
        ) else { throw OfflineMapsFailure.invalidSelection }
        return options
    }
}
