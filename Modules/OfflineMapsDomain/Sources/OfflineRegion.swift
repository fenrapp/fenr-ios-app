import Foundation

public enum OfflineLayer: String, Codable, CaseIterable, Sendable {
    case topographic
    case satellite
}

public enum OfflineCoverage: Sendable {
    case unavailable
    case partial
    case complete
}

public enum OfflineDownloadStatus: String, Codable, Sendable {
    case queued
    case downloading
    case paused
    case waitingForWiFi
    case interrupted
    case ready
    case failed
}

public enum OfflineMapsFailure: String, Error, Codable, Sendable {
    case invalidSelection
    case insufficientStorage
    case providerLimit
    case network
    case configuration
    case catalog
    case provider
}

public struct OfflineLayerRecord: Codable, Equatable, Sendable {
    public let layer: OfflineLayer
    public var resourceID: String
    public var pendingResourceID: String?
    public var resourceBytes: UInt64?
    public var available: Bool
    public var updatedAt: Date?

    public init(layer: OfflineLayer, resourceID: String, available: Bool = false, updatedAt: Date? = nil) {
        self.layer = layer
        self.resourceID = resourceID
        self.available = available
        self.updatedAt = updatedAt
    }
}

public struct OfflineRegion: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public let geometry: OfflineGeometry
    public let routeID: UUID?
    public var layers: [OfflineLayerRecord]
    public let maximumZoom: UInt8
    public var status: OfflineDownloadStatus
    public var progress: Double
    public var completedBytes: UInt64
    public var failure: OfflineMapsFailure?
    public let createdAt: Date
    public var isUpdating: Bool

    public init(
        id: UUID, name: String, geometry: OfflineGeometry, routeID: UUID?, layers: [OfflineLayerRecord], now: Date
    ) {
        self.id = id
        self.name = name
        self.geometry = geometry
        self.routeID = routeID
        self.layers = layers
        maximumZoom = 16
        status = .queued
        progress = 0
        completedBytes = 0
        createdAt = now
        isUpdating = false
    }
}
