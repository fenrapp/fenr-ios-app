import Foundation

public struct OfflineMapsSnapshot: Equatable, Sendable {
    public let regions: [OfflineRegion]
    public let usedBytes: Int64
    public let freeBytes: Int64
    public let wifiOnly: Bool
    public let isDownloadNetworkAllowed: Bool
    public let isConnected: Bool
    public let isReconciled: Bool
    public let failure: OfflineMapsFailure?

    public init(
        regions: [OfflineRegion], usedBytes: Int64, freeBytes: Int64,
        wifiOnly: Bool, isConnected: Bool, isReconciled: Bool, failure: OfflineMapsFailure?,
        isDownloadNetworkAllowed: Bool = true
    ) {
        self.isDownloadNetworkAllowed = isDownloadNetworkAllowed
        self.regions = regions
        self.usedBytes = usedBytes
        self.freeBytes = freeBytes
        self.wifiOnly = wifiOnly
        self.isConnected = isConnected
        self.isReconciled = isReconciled
        self.failure = failure
    }
}

public struct OfflineMapEstimate: Equatable, Sendable {
    public let transferBytes: UInt64
    public let storageBytes: UInt64

    public init(transferBytes: UInt64, storageBytes: UInt64) {
        self.transferBytes = transferBytes
        self.storageBytes = storageBytes
    }
}

public struct OfflineMapRequest: Sendable {
    public let name: String
    public let geometry: OfflineGeometry
    public let routeID: UUID?
    public let satellite: Bool

    public init(name: String, geometry: OfflineGeometry, routeID: UUID?, satellite: Bool) {
        self.name = name
        self.geometry = geometry
        self.routeID = routeID
        self.satellite = satellite
    }
}

public enum OfflineMapCommand: Sendable {
    case pause(UUID)
    case resume(UUID)
    case update(UUID)
    case delete(UUID)
    case rename(UUID, String)
    case wifiOnly(Bool)
}

@MainActor
public protocol OfflineMapsRepository: AnyObject {
    var snapshot: OfflineMapsSnapshot { get }
    func observe(_ observer: @escaping @MainActor (OfflineMapsSnapshot) -> Void) -> UUID
    func removeObserver(_ id: UUID)
    func estimate(_ request: OfflineMapRequest) async throws -> OfflineMapEstimate
    func enqueue(_ request: OfflineMapRequest, estimate: OfflineMapEstimate) throws
    func perform(_ command: OfflineMapCommand) async throws
    func setActive(_ active: Bool)
}

@MainActor
public struct OfflineMapsUseCases {
    private let repository: any OfflineMapsRepository
    public let geometry: OfflineGeometryService

    public init(repository: any OfflineMapsRepository, geometry: OfflineGeometryService) {
        self.repository = repository
        self.geometry = geometry
    }

    public var snapshot: OfflineMapsSnapshot { repository.snapshot }
    public func observe(_ observer: @escaping @MainActor (OfflineMapsSnapshot) -> Void) -> UUID {
        repository.observe(observer)
    }
    public func removeObserver(_ id: UUID) { repository.removeObserver(id) }
    public func estimate(_ request: OfflineMapRequest) async throws -> OfflineMapEstimate {
        try await repository.estimate(request)
    }
    public func enqueue(_ request: OfflineMapRequest, estimate: OfflineMapEstimate) throws {
        try repository.enqueue(request, estimate: estimate)
    }
    public func perform(_ command: OfflineMapCommand) async throws { try await repository.perform(command) }
}
