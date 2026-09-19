import Foundation
import OfflineMapsDomain

@MainActor
final class OfflineMapsRepositorySpy: OfflineMapsRepository {
    var regions: [OfflineRegion] = []
    var commands: [OfflineMapCommand] = []
    var estimates: [OfflineMapRequest] = []
    var suspendsCommands = false
    private var pendingCommands: [Int: CheckedContinuation<Void, any Error>] = [:]
    private var pendingEstimates: [Int: CheckedContinuation<OfflineMapEstimate, any Error>] = [:]
    private var observers: [UUID: @MainActor (OfflineMapsSnapshot) -> Void] = [:]

    var snapshot: OfflineMapsSnapshot {
        OfflineMapsSnapshot(
            regions: regions, usedBytes: 0, freeBytes: 10_000_000_000,
            wifiOnly: true, isConnected: true, isReconciled: true, failure: nil
        )
    }

    func observe(_ observer: @escaping @MainActor (OfflineMapsSnapshot) -> Void) -> UUID {
        let id = UUID()
        observers[id] = observer
        observer(snapshot)
        return id
    }

    func removeObserver(_ id: UUID) { observers[id] = nil }
    func enqueue(_ request: OfflineMapRequest, estimate: OfflineMapEstimate) throws {}
    func setActive(_ active: Bool) {}

    func estimate(_ request: OfflineMapRequest) async throws -> OfflineMapEstimate {
        let index = estimates.count
        estimates.append(request)
        return try await withCheckedThrowingContinuation { pendingEstimates[index] = $0 }
    }

    func perform(_ command: OfflineMapCommand) async throws {
        let index = commands.count
        commands.append(command)
        if suspendsCommands {
            try await withCheckedThrowingContinuation { pendingCommands[index] = $0 }
        }
    }

    func completeCommand(_ index: Int, failure: OfflineMapsFailure? = nil) {
        let continuation = pendingCommands.removeValue(forKey: index)
        if let failure { continuation?.resume(throwing: failure) } else { continuation?.resume() }
    }

    func completeEstimate(_ index: Int, storageBytes: UInt64 = 100) {
        pendingEstimates.removeValue(forKey: index)?.resume(returning: OfflineMapEstimate(
            transferBytes: storageBytes, storageBytes: storageBytes
        ))
    }
}
