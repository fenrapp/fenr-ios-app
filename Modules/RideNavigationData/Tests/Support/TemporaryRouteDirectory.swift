import Foundation

final class TemporaryRouteDirectory {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("fenr-route-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }

    func routeURL(id: UUID) -> URL {
        url.appendingPathComponent(id.uuidString).appendingPathExtension("fenrroute")
    }

    var draftURL: URL {
        url.appendingPathComponent("active-draft.json")
    }
}
