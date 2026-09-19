import Foundation
@testable import RideNavigation
import Testing

@MainActor
struct RideNavigationFileImportTests {
    @Test("GPX and XML filenames reach the importer without consulting provider content types", arguments: [
        "gpx", "GPX", "xml", "XML"
    ])
    func acceptsRouteFileExtensions(fileExtension: String) throws {
        let route = LibraryControllerTestRoutes.route(name: "Imported route")
        let controller = LibraryControllerTestFactory.makeController(
            repository: LibraryControllerRouteRepository(), importer: FixedGPXRouteImporter(routes: [route])
        )
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension(fileExtension)
        try Data("synthetic importer input".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(try controller.importGPX(from: url) == [route])
    }

    @Test("Unrelated files remain rejected after broadening the document picker", arguments: [
        "jpg", "pdf", "zip", "gpx.zip", ""
    ])
    func rejectsOtherFileExtensions(fileExtension: String) throws {
        let route = LibraryControllerTestRoutes.route(name: "Must not import")
        let controller = LibraryControllerTestFactory.makeController(
            repository: LibraryControllerRouteRepository(), importer: FixedGPXRouteImporter(routes: [route])
        )
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension(fileExtension)
        try Data("synthetic importer input".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(throws: CocoaError(.fileReadCorruptFile)) {
            try controller.importGPX(from: url)
        }
    }
}
