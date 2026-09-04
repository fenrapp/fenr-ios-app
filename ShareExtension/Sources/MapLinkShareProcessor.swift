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
        let providers = inputItems
            .compactMap(\.attachments)
            .flatMap({ $0 })

        if let provider = providers.first(where: { Self.gpxTypeIdentifier(for: $0) != nil }),
           let typeIdentifier = Self.gpxTypeIdentifier(for: provider) {
            let data = try await loadDataRepresentation(
                from: provider,
                typeIdentifier: typeIdentifier
            )
            try await persistGPX(data: data)
            return
        }

        guard let provider = providers.first(where: Self.canLoadURL) else {
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
        let pathExtension = url.pathExtension.lowercased()
        guard url.isFileURL,
              Constants.supportedFileExtensions.contains(pathExtension) else {
            throw MapLinkShareError.unsupportedURL
        }
        try await copyAndPersistFile(at: url, pathExtension: pathExtension)
    }
}

private extension MapLinkShareProcessor {
    static func gpxTypeIdentifier(for provider: NSItemProvider) -> String? {
        if provider.hasItemConformingToTypeIdentifier(Constants.gpxTypeIdentifier) {
            return Constants.gpxTypeIdentifier
        }
        guard provider.suggestedName?.lowercased().hasSuffix(".gpx") == true else {
            return nil
        }
        return provider.registeredTypeIdentifiers.first { identifier in
            identifier == UTType.xml.identifier
                || identifier == UTType.data.identifier
                || UTType(identifier)?.conforms(to: .xml) == true
        }
    }

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

    func loadDataRepresentation(
        from provider: NSItemProvider,
        typeIdentifier: String
    ) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, error in
                if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: error ?? MapLinkShareError.unsupportedURL)
                }
            }
        }
    }

    func persistGPX(data: Data) async throws {
        guard data.count <= Constants.maximumGPXFileSizeBytes else {
            throw MapLinkShareError.unsupportedURL
        }
        let destinationURL = try managedDestinationURL(pathExtension: Constants.gpxFileExtension)
        let temporaryURL = temporaryURL(for: destinationURL)
        do {
            try data.write(to: temporaryURL, options: .atomic)
            try Task.checkCancellation()
            try fileManager.moveItem(at: temporaryURL, to: destinationURL)
            try await persistManagedFile(destinationURL)
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            try? fileManager.removeItem(at: destinationURL)
            throw error
        }
    }

    func copyAndPersistFile(at sourceURL: URL, pathExtension: String) async throws {
        let accessedResource = startAccessingSecurityScopedResource(sourceURL)
        defer {
            if accessedResource {
                stopAccessingSecurityScopedResource(sourceURL)
            }
        }
        let destinationURL = try managedDestinationURL(pathExtension: pathExtension)
        let temporaryURL = temporaryURL(for: destinationURL)
        do {
            try fileManager.copyItem(at: sourceURL, to: temporaryURL)
            try Task.checkCancellation()
            try fileManager.moveItem(at: temporaryURL, to: destinationURL)
            try await persistManagedFile(destinationURL)
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            try? fileManager.removeItem(at: destinationURL)
            throw error
        }
    }

    func managedDestinationURL(pathExtension: String) throws -> URL {
        let directory = sharedContainerURL.appendingPathComponent(
            Constants.importDirectoryName,
            isDirectory: true
        )
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(
            Constants.managedFilePrefix
                + makeIdentifier().uuidString
                + "."
                + pathExtension
        )
    }

    func temporaryURL(for destinationURL: URL) -> URL {
        destinationURL.deletingLastPathComponent().appendingPathComponent(
            ".\(destinationURL.lastPathComponent).temporary"
        )
    }

    func persistManagedFile(_ destinationURL: URL) async throws {
        try Task.checkCancellation()
        try await persist(url: destinationURL)
        removeManagedCopies(except: destinationURL)
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
            && Constants.supportedFileExtensions.contains(url.pathExtension.lowercased())
    }

    enum Constants {
        static let appGroupIdentifier = "group.com.fenr.app.shared"
        static let importDirectoryName = "IncomingMapLinks"
        static let managedFilePrefix = "FENRIncoming-"
        static let directionsRequestExtension = "directionsrequest"
        static let gpxFileExtension = "gpx"
        static let gpxTypeIdentifier = "com.topografix.gpx"
        static let supportedFileExtensions: Set<String> = [
            directionsRequestExtension,
            gpxFileExtension
        ]
        static let maximumGPXFileSizeBytes = 25 * 1_024 * 1_024
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
