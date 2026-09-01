import Foundation
import RideNavigationData
import RideNavigationDomain
import UniformTypeIdentifiers

@MainActor
protocol MapLinkShareProcessing {
    func process(inputItems: [NSExtensionItem]) async throws
}

@MainActor
struct MapLinkShareProcessor: MapLinkShareProcessing {
    private let store: any IncomingMapLinkStoring
    private let fileManager: FileManager
    private let sharedContainerURL: URL
    private let now: () -> Date
    private let makeIdentifier: () -> UUID
    private let startAccessingSecurityScopedResource: (URL) -> Bool
    private let stopAccessingSecurityScopedResource: (URL) -> Void

    init(
        store: any IncomingMapLinkStoring,
        fileManager: FileManager,
        sharedContainerURL: URL,
        now: @escaping () -> Date,
        makeIdentifier: @escaping () -> UUID,
        startAccessingSecurityScopedResource: @escaping (URL) -> Bool,
        stopAccessingSecurityScopedResource: @escaping (URL) -> Void
    ) {
        self.store = store
        self.fileManager = fileManager
        self.sharedContainerURL = sharedContainerURL
        self.now = now
        self.makeIdentifier = makeIdentifier
        self.startAccessingSecurityScopedResource = startAccessingSecurityScopedResource
        self.stopAccessingSecurityScopedResource = stopAccessingSecurityScopedResource
    }

    static func live() throws -> MapLinkShareProcessor {
        let fileManager = FileManager.default
        guard let sharedContainerURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: Constants.appGroupIdentifier
        ) else {
            throw MapLinkShareError.sharedContainerUnavailable
        }
        return MapLinkShareProcessor(
            store: try UserDefaultsIncomingMapLinkStore.shared(),
            fileManager: fileManager,
            sharedContainerURL: sharedContainerURL,
            now: Date.init,
            makeIdentifier: UUID.init,
            startAccessingSecurityScopedResource: { $0.startAccessingSecurityScopedResource() },
            stopAccessingSecurityScopedResource: { $0.stopAccessingSecurityScopedResource() }
        )
    }

    func process(inputItems: [NSExtensionItem]) async throws {
        try Task.checkCancellation()
        guard let provider = inputItems
            .compactMap(\.attachments)
            .flatMap({ $0 })
            .first(where: Self.canLoadURL) else {
            throw MapLinkShareError.missingURL
        }
        let typeIdentifier = provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
            ? UTType.fileURL.identifier
            : UTType.url.identifier
        let item = try await provider.loadItem(forTypeIdentifier: typeIdentifier)
        try Task.checkCancellation()
        guard let url = item as? URL else {
            throw MapLinkShareError.unsupportedURL
        }
        try await process(url: url)
    }

    func process(url: URL) async throws {
        try Task.checkCancellation()
        if Self.isAllowedWebURL(url) {
            try await persist(url: url)
            removeManagedCopies()
            return
        }
        guard url.isFileURL,
              url.pathExtension.lowercased() == Constants.directionsRequestExtension else {
            throw MapLinkShareError.unsupportedURL
        }
        try await copyAndPersistDirectionsRequest(at: url)
    }
}

private extension MapLinkShareProcessor {
    static func canLoadURL(_ provider: NSItemProvider) -> Bool {
        provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
            || provider.hasItemConformingToTypeIdentifier(UTType.url.identifier)
    }

    static func isAllowedWebURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https",
              let host = url.host?.lowercased() else { return false }
        return Constants.allowedHosts.contains(host)
    }

    func persist(url: URL) async throws {
        try Task.checkCancellation()
        try await store.save(IncomingMapLink(url: url, receivedAt: now()))
    }

    func copyAndPersistDirectionsRequest(at sourceURL: URL) async throws {
        let accessedResource = startAccessingSecurityScopedResource(sourceURL)
        defer {
            if accessedResource {
                stopAccessingSecurityScopedResource(sourceURL)
            }
        }
        let directory = sharedContainerURL.appendingPathComponent(
            Constants.importDirectoryName,
            isDirectory: true
        )
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let destinationURL = directory.appendingPathComponent(
            Constants.managedFilePrefix
                + makeIdentifier().uuidString
                + "."
                + Constants.directionsRequestExtension
        )
        let temporaryURL = directory.appendingPathComponent(
            ".\(destinationURL.lastPathComponent).temporary"
        )
        do {
            try fileManager.copyItem(at: sourceURL, to: temporaryURL)
            try Task.checkCancellation()
            try fileManager.moveItem(at: temporaryURL, to: destinationURL)
            try Task.checkCancellation()
            try await persist(url: destinationURL)
            removeManagedCopies(except: destinationURL)
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            try? fileManager.removeItem(at: destinationURL)
            throw error
        }
    }

    func removeManagedCopies(except retainedURL: URL? = nil) {
        let directory = sharedContainerURL.appendingPathComponent(
            Constants.importDirectoryName,
            isDirectory: true
        )
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }
        for url in contents where Self.isManagedCopy(url) && url != retainedURL {
            try? fileManager.removeItem(at: url)
        }
    }

    static func isManagedCopy(_ url: URL) -> Bool {
        url.lastPathComponent.hasPrefix(Constants.managedFilePrefix)
            && url.pathExtension.lowercased() == Constants.directionsRequestExtension
    }

    enum Constants {
        static let appGroupIdentifier = "group.com.fenr.app.shared"
        static let importDirectoryName = "IncomingMapLinks"
        static let managedFilePrefix = "FENRIncoming-"
        static let directionsRequestExtension = "directionsrequest"
        static let allowedHosts: Set<String> = [
            "maps.app.goo.gl",
            "goo.gl",
            "google.com",
            "www.google.com",
            "maps.google.com",
            "maps.apple.com"
        ]
    }
}

enum MapLinkShareError: Error, Equatable {
    case missingURL
    case unsupportedURL
    case sharedContainerUnavailable
}
