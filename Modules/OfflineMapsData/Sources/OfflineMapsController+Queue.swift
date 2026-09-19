import Foundation
import OfflineMapsDomain

@MainActor
extension OfflineMapsController {
    func schedule() {
        guard active, reconciled, connection.connected, !catalog.wifiOnly || connection.wifi else { return }
        guard !catalog.regions.contains(where: { $0.status == .downloading }) else { return }
        let eligible: [OfflineDownloadStatus] = [.queued, .interrupted, .waitingForWiFi]
        guard let region = catalog.regions.first(where: { eligible.contains($0.status) }) else { return }
        let previous = worker
        generation += 1
        let current = generation
        mutate(region.id) { $0.status = .downloading }
        worker = Task { [weak self] in
            await withTaskCancellationHandler { await previous?.value } onCancel: { previous?.cancel() }
            guard !Task.isCancelled, let self, self.generation == current else { return }
            await self.download(region, generation: current)
        }
        publish()
    }

    func download(_ region: OfflineRegion, generation current: Int) async {
        do {
            for (index, layer) in region.layers.enumerated() where !layer.available || region.isUpdating {
                try checkStorage(required: 0)
                let resourceID: String
                if region.isUpdating {
                    resourceID = layer.pendingResourceID
                        ?? "fenr-\(region.id.uuidString)-\(layer.layer.rawValue)-\(UUID().uuidString)"
                    mutate(region.id) { $0.layers[index].pendingResourceID = resourceID }
                    try save()
                } else {
                    resourceID = layer.resourceID
                }
                let quota = storageStatus.usedBytes + storageStatus.freeBytes - Self.storageReserve
                backend.setStorageLimit(UInt64(max(0, quota)))
                try await backend.download(
                    resourceID: resourceID, geometry: region.geometry, layer: layer.layer, wifiOnly: catalog.wifiOnly
                ) { [weak self] progress in
                    guard let self, self.generation == current else { throw CancellationError() }
                    if self.now().timeIntervalSince(self.storageCheckedAt) > 1 {
                        try self.checkStorage(required: 0)
                    }
                    self.mutate(region.id) {
                        $0.progress = (Double(index) + progress.fraction) / Double(region.layers.count)
                        $0.layers[index].resourceBytes = progress.bytes
                        $0.completedBytes = $0.layers.reduce(0) { $0 + ($1.resourceBytes ?? 0) }
                    }
                    self.publish()
                }
                try Task.checkCancellation()
                guard generation == current else { return }
                if resourceID != layer.resourceID {
                    catalog.retiredResourceIDs = (catalog.retiredResourceIDs ?? []) + [layer.resourceID]
                }
                mutate(region.id) {
                    $0.layers[index].available = true
                    $0.layers[index].updatedAt = now()
                    $0.layers[index].resourceID = resourceID
                    $0.layers[index].pendingResourceID = nil
                }
                try save()
                await removeRetiredResources()
                try Task.checkCancellation()
                guard generation == current else { return }
            }
            mutate(region.id) { $0.status = .ready; $0.progress = 1; $0.isUpdating = false; $0.failure = nil }
        } catch {
            guard generation == current, !Task.isCancelled else { return }
            mutate(region.id) { $0.status = .failed; $0.failure = (error as? OfflineMapsFailure) ?? .provider }
        }
        guard generation == current else { return }
        do { try save() } catch { failure = .catalog; publish() }
        schedule()
    }

    func removeRetiredResources() async {
        for id in catalog.retiredResourceIDs ?? [] {
            guard !Task.isCancelled else { return }
            do {
                try await backend.delete(resourceID: id)
                catalog.retiredResourceIDs?.removeAll { $0 == id }
                try save()
            } catch {
                // Keep the identifier until a later reconciliation can reclaim it.
                return
            }
        }
    }

    func interrupt(status: OfflineDownloadStatus) {
        generation += 1
        worker?.cancel()
        for index in catalog.regions.indices where catalog.regions[index].status == .downloading {
            catalog.regions[index].status = status
        }
        if reconciled { try? save() }
        publish()
    }

}
