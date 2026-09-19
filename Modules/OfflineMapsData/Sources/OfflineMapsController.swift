import Foundation
import OfflineMapsDomain

@MainActor
public final class OfflineMapsController: OfflineMapsRepository {
    public static let storageReserve: Int64 = 1_000_000_000
    let backend: any OfflineMapsBackend
    let storage: any OfflineMapsStorage
    let network: any OfflineNetworkMonitoring
    let now: @Sendable () -> Date
    var catalog = OfflineCatalog()
    var storageStatus = OfflineStorageStatus(usedBytes: 0, freeBytes: 0)
    var connection = OfflineNetworkState(connected: false, wifi: false)
    var reconciled = false
    var active = false
    var failure: OfflineMapsFailure?
    var observers: [UUID: @MainActor (OfflineMapsSnapshot) -> Void] = [:]
    var worker: Task<Void, Never>?
    var startup: Task<Void, Never>?
    var networkTask: Task<Void, Never>?
    var generation = 0
    var storageCheckedAt = Date.distantPast

    public init(
        backend: any OfflineMapsBackend, storage: any OfflineMapsStorage,
        network: any OfflineNetworkMonitoring, now: @escaping @Sendable () -> Date
    ) {
        self.backend = backend
        self.storage = storage
        self.network = network
        self.now = now
    }

    deinit {
        worker?.cancel()
        startup?.cancel()
        networkTask?.cancel()
    }

    public var snapshot: OfflineMapsSnapshot {
        OfflineMapsSnapshot(
            regions: catalog.regions, usedBytes: storageStatus.usedBytes, freeBytes: storageStatus.freeBytes,
            wifiOnly: catalog.wifiOnly, isConnected: connection.connected, isReconciled: reconciled, failure: failure,
            isDownloadNetworkAllowed: connection.connected && (!catalog.wifiOnly || connection.wifi)
        )
    }

    public func observe(_ observer: @escaping @MainActor (OfflineMapsSnapshot) -> Void) -> UUID {
        let id = UUID()
        observers[id] = observer
        observer(snapshot)
        return id
    }

    public func removeObserver(_ id: UUID) { observers[id] = nil }

    public func setActive(_ active: Bool) {
        self.active = active
        if !active {
            interrupt(status: .interrupted)
            return
        }
        if networkTask == nil { observeNetwork() }
        if !reconciled, startup == nil {
            startup = Task { [weak self] in await self?.reconcile() }
        } else {
            schedule()
        }
    }

    public func estimate(_ request: OfflineMapRequest) async throws -> OfflineMapEstimate {
        guard request.geometry.isValid else { throw OfflineMapsFailure.invalidSelection }
        guard connection.connected, !catalog.wifiOnly || connection.wifi else { throw OfflineMapsFailure.network }
        var transfer: UInt64 = 0
        var size: UInt64 = 0
        for layer in request.satellite ? OfflineLayer.allCases : [.topographic] {
            let value = try await backend.estimate(geometry: request.geometry, layer: layer)
            try Task.checkCancellation()
            transfer += value.transferBytes
            size += value.storageBytes
        }
        return OfflineMapEstimate(transferBytes: transfer, storageBytes: size)
    }

    public func enqueue(_ request: OfflineMapRequest, estimate: OfflineMapEstimate) throws {
        guard reconciled else { throw OfflineMapsFailure.catalog }
        guard request.geometry.isValid, !request.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OfflineMapsFailure.invalidSelection
        }
        try checkStorage(required: estimate.storageBytes)
        let previous = catalog
        if let routeID = request.routeID, let index = catalog.regions.firstIndex(where: {
            $0.routeID == routeID && $0.geometry == request.geometry && $0.layers.allSatisfy(\.available)
        }) {
            if request.satellite, !catalog.regions[index].layers.contains(where: { $0.layer == .satellite }) {
                let id = catalog.regions[index].id
                catalog.regions[index].layers.append(OfflineLayerRecord(
                    layer: .satellite, resourceID: "fenr-\(id.uuidString)-satellite"
                ))
                catalog.regions[index].status = .queued
            }
        } else {
            let id = UUID()
            let layers = (request.satellite ? OfflineLayer.allCases : [.topographic]).map {
                OfflineLayerRecord(layer: $0, resourceID: "fenr-\(id.uuidString)-\($0.rawValue)")
            }
            catalog.regions.append(OfflineRegion(
                id: id, name: request.name, geometry: request.geometry,
                routeID: request.routeID, layers: layers, now: now()
            ))
        }
        do { try save() } catch { catalog = previous; throw error }
        schedule()
    }

    public func perform(_ command: OfflineMapCommand) async throws {
        switch command {
        case .wifiOnly(let value):
            catalog.wifiOnly = value
            if value && !connection.wifi { interrupt(status: .waitingForWiFi) }
        case .pause(let id):
            if catalog.regions.first(where: { $0.id == id })?.status == .downloading {
                interrupt(status: .paused)
                await worker?.value
            }
            mutate(id) { $0.status = .paused }
        case .resume(let id):
            mutate(id) { $0.status = .queued; $0.failure = nil }
        case .rename(let id, let name):
            let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { throw OfflineMapsFailure.invalidSelection }
            mutate(id) { $0.name = name }
        case .update(let id):
            guard catalog.regions.first(where: { $0.id == id })?.status != .downloading else { return }
            mutate(id) { $0.isUpdating = true; $0.status = .queued; $0.failure = nil }
        case .delete(let id):
            if catalog.regions.first(where: { $0.id == id })?.status == .downloading {
                interrupt(status: .paused)
                await worker?.value
            }
            guard let region = catalog.regions.first(where: { $0.id == id }) else { return }
            for (index, layer) in region.layers.enumerated() {
                if let pending = layer.pendingResourceID { try await backend.delete(resourceID: pending) }
                try await backend.delete(resourceID: layer.resourceID)
                mutate(id) { $0.layers[index].available = false }
                try save()
            }
            catalog.regions.removeAll { $0.id == id }
        }
        try save()
        schedule()
    }

    func reconcile() async {
        defer { startup = nil }
        do {
            catalog = try storage.read()
            await removeRetiredResources()
            let resources = try await backend.availableResources()
            try Task.checkCancellation()
            for index in catalog.regions.indices {
                for layer in catalog.regions[index].layers.indices {
                    let id = catalog.regions[index].layers[layer].resourceID
                    catalog.regions[index].layers[layer].available = resources.contains(id)
                }
                if catalog.regions[index].status == .downloading { catalog.regions[index].status = .interrupted }
                if catalog.regions[index].status == .ready,
                   !catalog.regions[index].layers.allSatisfy(\.available) {
                    catalog.regions[index].status = .failed
                    catalog.regions[index].failure = .provider
                }
            }
            reconciled = true
            failure = nil
            try save()
            schedule()
        } catch {
            failure = .catalog
            publish()
        }
    }

    func observeNetwork() {
        let states = network.states()
        networkTask = Task { [weak self] in
            for await state in states {
                guard !Task.isCancelled, let self else { return }
                self.connection = state
                if !state.connected || (self.catalog.wifiOnly && !state.wifi) {
                    self.interrupt(status: .waitingForWiFi)
                }
                self.publish()
                self.schedule()
            }
        }
    }

    func mutate(_ id: UUID, _ change: (inout OfflineRegion) -> Void) {
        guard let index = catalog.regions.firstIndex(where: { $0.id == id }) else { return }
        change(&catalog.regions[index])
    }

    func checkStorage(required: UInt64) throws {
        storageStatus = try storage.status()
        storageCheckedAt = now()
        guard storageStatus.freeBytes > Self.storageReserve,
              required < UInt64(storageStatus.freeBytes - Self.storageReserve) else {
            throw OfflineMapsFailure.insufficientStorage
        }
    }

    func save() throws {
        try storage.write(catalog)
        storageStatus = try storage.status()
        publish()
    }

    func publish() {
        let value = snapshot
        for observer in observers.values { observer(value) }
    }
}
