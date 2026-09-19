import Foundation
import OfflineMapsData
import OfflineMapsDomain

@MainActor
final class OfflineBackendStub: OfflineMapsBackend {
    struct Call {
        let id: String
        let layer: OfflineLayer
        let continuation: AsyncThrowingStream<Void, Error>.Continuation
        let progress: @MainActor (OfflineDownloadProgress) throws -> Void
    }

    var calls: [Call] = []
    var resources: Set<String> = []
    var deleted: [String] = []
    var limits: [UInt64] = []
    var estimateValue = OfflineMapEstimate(transferBytes: 100, storageBytes: 100)
    var reconciliationFails = false

    func setStorageLimit(_ bytes: UInt64) { limits.append(bytes) }
    func estimate(geometry: OfflineGeometry, layer: OfflineLayer) async throws -> OfflineMapEstimate { estimateValue }
    func availableResources() async throws -> Set<String> {
        if reconciliationFails { throw OfflineMapsFailure.provider }
        return resources
    }
    func delete(resourceID: String) async throws { deleted.append(resourceID); resources.remove(resourceID) }

    func download(
        resourceID: String, geometry: OfflineGeometry, layer: OfflineLayer, wifiOnly: Bool,
        progress: @escaping @MainActor (OfflineDownloadProgress) throws -> Void
    ) async throws {
        let (stream, continuation) = AsyncThrowingStream<Void, Error>.makeStream()
        calls.append(Call(id: resourceID, layer: layer, continuation: continuation, progress: progress))
        for try await _ in stream {}
        try Task.checkCancellation()
        resources.insert(resourceID)
    }

    func complete(_ index: Int) { calls[index].continuation.finish() }
    func fail(_ index: Int, error: OfflineMapsFailure = .provider) {
        calls[index].continuation.finish(throwing: error)
    }
}
