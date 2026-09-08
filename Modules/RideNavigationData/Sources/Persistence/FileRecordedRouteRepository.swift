import Foundation
import RideNavigationDomain

public actor FileRecordedRouteRepository: RecordedRouteRepository {
    let fileManager: FileManager
    let directoryURL: URL
    let codec: any StoredRideRouteCoding
    var summaryCache: [UUID: StoredRideRouteSummary] = [:]

    public init(
        fileManager: sending FileManager,
        directoryURL: URL,
        codec: any StoredRideRouteCoding
    ) {
        self.fileManager = fileManager
        self.directoryURL = directoryURL
        self.codec = codec
    }

    public func save(_ route: RideRoute) async throws {
        try Task.checkCancellation()
        try prepareDirectory()
        try Task.checkCancellation()
        let url = routeURL(id: route.id)
        let data = try codec.encode(route)
        try data.write(to: url, options: Self.writeOptions)
        summaryCache[route.id] = nil
        cacheSummary(of: route, matching: data, at: url)
    }

    public func delete(id: UUID) async throws {
        try Task.checkCancellation()
        let url = routeURL(id: id)
        if fileManager.fileExists(atPath: url.path) {
            try Task.checkCancellation()
            try fileManager.removeItem(at: url)
        }
        summaryCache[id] = nil
        try? fileManager.removeItem(at: summaryURL(id: id))
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

    func prepareDirectory() throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    func routeURL(id: UUID) -> URL {
        directoryURL.appendingPathComponent(id.uuidString).appendingPathExtension(Constants.routeExtension)
    }

    private var draftURL: URL {
        directoryURL.appendingPathComponent(Constants.draftFilename)
    }

    static let writeOptions: Data.WritingOptions = [
        .atomic,
        .completeFileProtectionUntilFirstUserAuthentication
    ]

    enum Constants {
        static let routeExtension = "fenrroute"
        static let draftFilename = "active-draft.json"
    }
}
