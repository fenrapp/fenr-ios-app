import Foundation

final class ReplacingRouteFileManager: FileManager, @unchecked Sendable {
    private let replacementURL: URL
    private let replacementData: Data
    private let lock = NSLock()
    private var shouldReplace = true

    init(replacementURL: URL, replacementData: Data) {
        self.replacementURL = replacementURL
        self.replacementData = replacementData
        super.init()
    }

    override func attributesOfItem(atPath path: String) throws -> [FileAttributeKey: Any] {
        let replace = lock.withLock {
            guard path == replacementURL.path, shouldReplace else { return false }
            shouldReplace = false
            return true
        }
        if replace { try replacementData.write(to: replacementURL, options: .atomic) }
        return try super.attributesOfItem(atPath: path)
    }
}
