import Foundation

final class FileOperationFailureController: @unchecked Sendable {
    private let lock = NSLock()
    private var removalPaths: Set<String> = []
    private var moveSourcePaths: Set<String> = []
    private var contentsPaths: Set<String> = []
    private var attributePaths: Set<String> = []

    func failNextRemoval(of url: URL) {
        _ = lock.withLock { removalPaths.insert(url.path) }
    }

    func failNextMove(from url: URL) {
        _ = lock.withLock { moveSourcePaths.insert(url.path) }
    }

    func failNextContents(of url: URL) {
        _ = lock.withLock { contentsPaths.insert(url.path) }
    }

    func failNextAttributes(of url: URL) {
        _ = lock.withLock { attributePaths.insert(url.path) }
    }

    func shouldFailRemoval(of url: URL) -> Bool {
        lock.withLock { removalPaths.remove(url.path) != nil }
    }

    func shouldFailMove(from url: URL) -> Bool {
        lock.withLock { moveSourcePaths.remove(url.path) != nil }
    }

    func shouldFailContents(of url: URL) -> Bool {
        lock.withLock { contentsPaths.remove(url.path) != nil }
    }

    func shouldFailAttributes(of url: URL) -> Bool {
        lock.withLock { attributePaths.remove(url.path) != nil }
    }
}

final class ControlledFileManager: FileManager, @unchecked Sendable {
    private let controller: FileOperationFailureController

    init(controller: FileOperationFailureController) {
        self.controller = controller
        super.init()
    }

    override func removeItem(at URL: URL) throws {
        if controller.shouldFailRemoval(of: URL) {
            throw CocoaError(.fileWriteUnknown)
        }
        try super.removeItem(at: URL)
    }

    override func moveItem(at srcURL: URL, to dstURL: URL) throws {
        if controller.shouldFailMove(from: srcURL) {
            throw CocoaError(.fileWriteUnknown)
        }
        try super.moveItem(at: srcURL, to: dstURL)
    }

    override func contentsOfDirectory(
        at url: URL,
        includingPropertiesForKeys keys: [URLResourceKey]?,
        options mask: DirectoryEnumerationOptions = []
    ) throws -> [URL] {
        if controller.shouldFailContents(of: url) {
            throw CocoaError(.fileReadUnknown)
        }
        return try super.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: keys,
            options: mask
        )
    }

    override func setAttributes(
        _ attributes: [FileAttributeKey: Any],
        ofItemAtPath path: String
    ) throws {
        if controller.shouldFailAttributes(of: URL(filePath: path)) {
            throw CocoaError(.fileWriteUnknown)
        }
        try super.setAttributes(attributes, ofItemAtPath: path)
    }
}
