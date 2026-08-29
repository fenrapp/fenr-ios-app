import EnvironmentDomain
import Foundation
import RideNavigationDomain

public actor FileRecordedRouteRepository: RecordedRouteRepository {
    private let fileManager: FileManager
    private let directoryURL: URL
    private let codec: StoredRideRouteCodec

    public init(
        fileManager: sending FileManager,
        directoryURL: URL,
        codec: StoredRideRouteCodec
    ) {
        self.fileManager = fileManager
        self.directoryURL = directoryURL
        self.codec = codec
    }

    public func loadRoutes() async -> [RideRoute] {
        do {
            try prepareDirectory()
            return try fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: nil
            )
            .filter { $0.pathExtension == Constants.routeExtension }
            .compactMap { url in
                try? codec.decode(Data(contentsOf: url))
            }
            .sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            return []
        }
    }

    public func save(_ route: RideRoute) async throws {
        try prepareDirectory()
        try codec.encode(route).write(to: routeURL(id: route.id), options: .atomic)
    }

    public func delete(id: UUID) async throws {
        let url = routeURL(id: id)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    public func loadDraft() async -> RideRoute? {
        try? codec.decode(Data(contentsOf: draftURL))
    }

    public func saveDraft(_ route: RideRoute?) async throws {
        try prepareDirectory()
        guard let route else {
            if fileManager.fileExists(atPath: draftURL.path) {
                try fileManager.removeItem(at: draftURL)
            }
            return
        }
        try codec.encode(route).write(to: draftURL, options: .atomic)
    }

    private func prepareDirectory() throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    private func routeURL(id: UUID) -> URL {
        directoryURL.appendingPathComponent(id.uuidString).appendingPathExtension(Constants.routeExtension)
    }

    private var draftURL: URL {
        directoryURL.appendingPathComponent(Constants.draftFilename)
    }

    private enum Constants {
        static let routeExtension = "fenrroute"
        static let draftFilename = "active-draft.json"
    }
}
