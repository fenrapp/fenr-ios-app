import Foundation
import OfflineMapsDomain

public struct OfflineCatalogStorage: OfflineMapsStorage {
    private let directory: URL
    private let fileManager: FileManager

    public init(directory: URL, fileManager: FileManager) {
        self.directory = directory
        self.fileManager = fileManager
    }

    public func read() throws -> OfflineCatalog {
        let path = directory.appendingPathComponent("catalog.json")
        guard fileManager.fileExists(atPath: path.path) else { return OfflineCatalog() }
        let catalog = try JSONDecoder().decode(OfflineCatalog.self, from: Data(contentsOf: path))
        guard catalog.version == 1, catalog.regions.allSatisfy({ $0.geometry.isValid }) else {
            throw OfflineMapsFailure.catalog
        }
        guard Set(catalog.regions.map(\.id)).count == catalog.regions.count else {
            throw OfflineMapsFailure.catalog
        }
        return catalog
    }

    public func write(_ catalog: OfflineCatalog) throws {
        try prepareDirectory()
        let data = try JSONEncoder().encode(catalog)
        try data.write(to: directory.appendingPathComponent("catalog.json"), options: .atomic)
    }

    public func status() throws -> OfflineStorageStatus {
        try prepareDirectory()
        let values = try directory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        let free = values.volumeAvailableCapacityForImportantUsage ?? 0
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey]
        let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: Array(keys))
        var size: Int64 = 0
        while let file = enumerator?.nextObject() as? URL {
            let values = try file.resourceValues(forKeys: keys)
            if values.isRegularFile == true {
                size += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
            }
        }
        return OfflineStorageStatus(usedBytes: size, freeBytes: free)
    }

    private func prepareDirectory() throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        var url = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
    }
}
