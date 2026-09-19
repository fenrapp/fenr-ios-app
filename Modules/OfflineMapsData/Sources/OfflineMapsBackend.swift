import Foundation
import OfflineMapsDomain

public struct OfflineDownloadProgress: Sendable {
    public let fraction: Double
    public let bytes: UInt64

    public init(fraction: Double, bytes: UInt64) {
        self.fraction = fraction
        self.bytes = bytes
    }
}

@MainActor
public protocol OfflineMapsBackend: AnyObject {
    func setStorageLimit(_ bytes: UInt64)
    func estimate(geometry: OfflineGeometry, layer: OfflineLayer) async throws -> OfflineMapEstimate
    func download(
        resourceID: String, geometry: OfflineGeometry, layer: OfflineLayer, wifiOnly: Bool,
        progress: @escaping @MainActor (OfflineDownloadProgress) throws -> Void
    ) async throws
    func availableResources() async throws -> Set<String>
    func delete(resourceID: String) async throws
}

public struct OfflineStorageStatus: Sendable {
    public let usedBytes: Int64
    public let freeBytes: Int64

    public init(usedBytes: Int64, freeBytes: Int64) {
        self.usedBytes = usedBytes
        self.freeBytes = freeBytes
    }
}

@MainActor
public protocol OfflineMapsStorage {
    func read() throws -> OfflineCatalog
    func write(_ catalog: OfflineCatalog) throws
    func status() throws -> OfflineStorageStatus
}

public struct OfflineCatalog: Codable, Sendable {
    public let version: Int
    public var regions: [OfflineRegion]
    public var retiredResourceIDs: [String]?
    public var wifiOnly: Bool

    public init(regions: [OfflineRegion] = [], wifiOnly: Bool = true) {
        version = 1
        retiredResourceIDs = []
        self.regions = regions
        self.wifiOnly = wifiOnly
    }
}
