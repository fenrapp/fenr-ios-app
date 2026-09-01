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
            try Task.checkCancellation()
            try prepareDirectory()
            let routeURLs = try fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: nil
            )
            var routes: [RideRoute] = []
            for url in routeURLs where url.pathExtension == Constants.routeExtension {
                try Task.checkCancellation()
                guard let filenameID = UUID(
                    uuidString: url.deletingPathExtension().lastPathComponent
                ),
                    let route = try? codec.decode(Data(contentsOf: url)),
                    route.id == filenameID else { continue }
                routes.append(route)
            }
            return routes.sorted(by: Self.isOrderedBefore)
        } catch {
            return []
        }
    }

    public func save(_ route: RideRoute) async throws {
        try Task.checkCancellation()
        try prepareDirectory()
        try Task.checkCancellation()
        try codec.encode(route).write(to: routeURL(id: route.id), options: Self.writeOptions)
    }

    public func delete(id: UUID) async throws {
        try Task.checkCancellation()
        let url = routeURL(id: id)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try Task.checkCancellation()
        try fileManager.removeItem(at: url)
    }

    public func loadDraft() async -> RideRoute? {
        do {
            try Task.checkCancellation()
            return try codec.decode(Data(contentsOf: draftURL))
        } catch {
            return nil
        }
    }

    public func saveDraft(_ route: RideRoute?) async throws {
        try Task.checkCancellation()
        try prepareDirectory()
        guard let route else {
            if fileManager.fileExists(atPath: draftURL.path) {
                try Task.checkCancellation()
                try fileManager.removeItem(at: draftURL)
            }
            return
        }
        try Task.checkCancellation()
        try codec.encode(route).write(to: draftURL, options: Self.writeOptions)
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

    private static func isOrderedBefore(_ lhs: RideRoute, _ rhs: RideRoute) -> Bool {
        if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    static let writeOptions: Data.WritingOptions = [
        .atomic,
        .completeFileProtectionUntilFirstUserAuthentication
    ]

    private enum Constants {
        static let routeExtension = "fenrroute"
        static let draftFilename = "active-draft.json"
    }
}
