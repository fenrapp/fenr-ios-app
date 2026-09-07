import Foundation

struct DebugUITestSession {
    let id: UUID
    let directory: URL
    let resetsStorage: Bool

    var suiteName: String { "com.fenr.app.debug.ui-tests.\(id.uuidString)" }
    var credentialService: String { suiteName + ".bike-lock" }

    static func parse(arguments: [String], applicationSupport: URL) throws -> Self? {
        guard arguments.contains("-uiTesting") else { return nil }
        guard let index = arguments.firstIndex(of: "-uiTestSession"),
              arguments.indices.contains(index + 1),
              let id = UUID(uuidString: arguments[index + 1]) else {
            throw ConfigurationError.invalidSession
        }
        return Self(
            id: id,
            directory: applicationSupport.appendingPathComponent("UITesting", isDirectory: true)
                .appendingPathComponent(id.uuidString, isDirectory: true),
            resetsStorage: arguments.contains("-uiTestReset")
        )
    }

    func prepare(
        fileManager: FileManager,
        clearCredentials: (String) throws -> Void
    ) throws -> UserDefaults {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw ConfigurationError.unavailableDefaults
        }
        if resetsStorage {
            defaults.removePersistentDomain(forName: suiteName)
            if fileManager.fileExists(atPath: directory.path) {
                try fileManager.removeItem(at: directory)
            }
            try clearCredentials(credentialService)
        }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return defaults
    }

    enum ConfigurationError: Error {
        case invalidSession
        case unavailableDefaults
    }
}
