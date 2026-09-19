import OfflineMapsData
import OfflineMapsDomain

@MainActor
final class OfflineStorageStub: OfflineMapsStorage {
    var catalog = OfflineCatalog()
    var free: Int64 = 10_000_000_000
    var used: Int64 = 100
    var writes = 0
    var failsWrites = false

    func read() throws -> OfflineCatalog { catalog }
    func write(_ catalog: OfflineCatalog) throws {
        if failsWrites { throw OfflineMapsFailure.catalog }
        self.catalog = catalog
        writes += 1
    }
    func status() throws -> OfflineStorageStatus { OfflineStorageStatus(usedBytes: used, freeBytes: free) }
}
