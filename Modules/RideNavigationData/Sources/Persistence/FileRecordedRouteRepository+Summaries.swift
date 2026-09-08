import Foundation
import RideNavigationDomain

extension FileRecordedRouteRepository {
    public func loadRouteSummaries() async -> [RideRouteSummary] {
        do {
            try Task.checkCancellation()
            try prepareDirectory()
            let urls = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
            var summaries: [RideRouteSummary] = []
            var presentIDs: Set<UUID> = []
            for url in urls where url.pathExtension == Constants.routeExtension {
                try Task.checkCancellation()
                guard let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent) else { continue }
                presentIDs.insert(id)
                if let summary = readSummary(id: id, at: url) { summaries.append(summary) }
            }
            try Task.checkCancellation()
            summaryCache = summaryCache.filter { presentIDs.contains($0.key) }
            return summaries.sorted {
                if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
                if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
                return $0.id.uuidString < $1.id.uuidString
            }
        } catch {
            return []
        }
    }

    public func loadRoute(id: UUID) async throws -> RideRoute? {
        try Task.checkCancellation()
        let url = routeURL(id: id)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let route = try codec.decode(Data(contentsOf: url))
        try Task.checkCancellation()
        guard route.id == id else { throw CocoaError(.fileReadCorruptFile) }
        return route
    }

    private func readSummary(id: UUID, at url: URL) -> RideRouteSummary? {
        let file = fileVersion(at: url)
        if let file {
            if let cached = summaryCache[id], cached.matches(id: id, file: file) { return cached.summary }
            if let data = try? Data(contentsOf: summaryURL(id: id)),
               let stored = try? JSONDecoder().decode(StoredRideRouteSummary.self, from: data),
               stored.matches(id: id, file: file) {
                summaryCache[id] = stored
                return stored.summary
            }
        }
        summaryCache[id] = nil
        guard !Task.isCancelled, let route = try? codec.decode(Data(contentsOf: url)), route.id == id else { return nil }
        guard !Task.isCancelled else { return nil }
        guard file == fileVersion(at: url) else { return nil }
        if let file { persistSummary(of: route, file: file) }
        return RideRouteSummary(route)
    }

    func cacheSummary(of route: RideRoute, matching savedData: Data, at url: URL) {
        guard let file = fileVersion(at: url),
              let currentData = try? Data(contentsOf: url), currentData == savedData,
              file == fileVersion(at: url) else { return }
        persistSummary(of: route, file: file)
    }

    private func persistSummary(of route: RideRoute, file: StoredRideRouteSummary.FileVersion) {
        let stored = StoredRideRouteSummary(file: file, summary: RideRouteSummary(route))
        summaryCache[route.id] = stored
        guard let data = try? JSONEncoder().encode(stored) else { return }
        try? data.write(to: summaryURL(id: route.id), options: Self.writeOptions)
    }

    private func fileVersion(at url: URL) -> StoredRideRouteSummary.FileVersion? {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path) else { return nil }
        return StoredRideRouteSummary.FileVersion(attributes: attributes)
    }

    func summaryURL(id: UUID) -> URL {
        directoryURL.appendingPathComponent(id.uuidString).appendingPathExtension("fenrsummary")
    }
}
