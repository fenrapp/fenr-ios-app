import Foundation
import RideNavigationDomain

actor MapLinkShareRecordingStore: IncomingMapLinkStoring {
    enum Failure: Error {
        case saveFailed
    }

    private let failsOnSave: Bool
    private var attemptedLinks: [IncomingMapLink] = []
    private var savedLinks: [IncomingMapLink] = []
    private var pendingLink: IncomingMapLink?

    init(failsOnSave: Bool = false, pendingLink: IncomingMapLink? = nil) {
        self.failsOnSave = failsOnSave
        self.pendingLink = pendingLink
    }

    func save(_ link: IncomingMapLink) throws {
        attemptedLinks.append(link)
        if failsOnSave {
            throw Failure.saveFailed
        }
        savedLinks.append(link)
        pendingLink = link
    }

    func consume() -> IncomingMapLink? { nil }
    func attempted() -> [IncomingMapLink] { attemptedLinks }
    func saved() -> [IncomingMapLink] { savedLinks }
    func pending() -> IncomingMapLink? { pendingLink }

    func seedPending(_ link: IncomingMapLink) {
        pendingLink = link
    }
}

@MainActor
final class MapLinkShareSecurityScopeRecorder {
    private(set) var startedURLs: [URL] = []
    private(set) var stoppedURLs: [URL] = []

    func start(_ url: URL) -> Bool {
        startedURLs.append(url)
        return true
    }

    func stop(_ url: URL) {
        stoppedURLs.append(url)
    }
}

actor MapLinkShareAsyncGate {
    private var blockedContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?
    private var isBlocked = false

    func wait() async {
        isBlocked = true
        blockedContinuation?.resume()
        blockedContinuation = nil
        await withCheckedContinuation { releaseContinuation = $0 }
    }

    func waitUntilBlocked() async {
        guard !isBlocked else { return }
        await withCheckedContinuation { blockedContinuation = $0 }
    }

    func open() {
        let continuation = releaseContinuation
        releaseContinuation = nil
        continuation?.resume()
    }
}

actor MapLinkShareRenderRecorder {
    private var renders = 0

    func render() {
        renders += 1
    }

    func count() -> Int { renders }
}

@MainActor
struct MapLinkShareTestFixture {
    let rootURL: URL
    let store: MapLinkShareRecordingStore
    let securityScope: MapLinkShareSecurityScopeRecorder
    let processor: MapLinkShareProcessor

    init(
        failsOnSave: Bool = false,
        pendingLink: IncomingMapLink? = nil
    ) throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("fenr-share-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let store = MapLinkShareRecordingStore(
            failsOnSave: failsOnSave,
            pendingLink: pendingLink
        )
        let securityScope = MapLinkShareSecurityScopeRecorder()
        self.rootURL = rootURL
        self.store = store
        self.securityScope = securityScope
        processor = MapLinkShareProcessor(
            store: store,
            fileManager: .default,
            sharedContainerURL: rootURL,
            now: { Date(timeIntervalSince1970: 1_700_000_000) },
            makeIdentifier: { UUID(uuidString: "00000000-0000-0000-0000-000000000001")! },
            startAccessingSecurityScopedResource: securityScope.start,
            stopAccessingSecurityScopedResource: securityScope.stop
        )
    }

    func removeTemporaryFiles() {
        try? FileManager.default.removeItem(at: rootURL)
    }

    var managedDirectoryURL: URL {
        rootURL.appendingPathComponent("IncomingMapLinks", isDirectory: true)
    }

    func writeFile(named name: String, contents: String = "fixture") throws -> URL {
        try FileManager.default.createDirectory(
            at: managedDirectoryURL,
            withIntermediateDirectories: true
        )
        let url = managedDirectoryURL.appendingPathComponent(name)
        try Data(contents.utf8).write(to: url)
        return url
    }
}
