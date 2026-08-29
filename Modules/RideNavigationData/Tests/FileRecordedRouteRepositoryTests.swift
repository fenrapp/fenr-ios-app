import Foundation
@testable import RideNavigationData
import RideNavigationDomain
import Testing

struct FileRecordedRouteRepositoryTests {
    @Test
    func savesLoadsAndClearsDraftRoutes() async throws {
        let directory = FileManager().temporaryDirectory
            .appendingPathComponent("fenr-route-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager().removeItem(at: directory) }
        let repository = FileRecordedRouteRepository(
            fileManager: FileManager(),
            directoryURL: directory,
            codec: StoredRideRouteCodec()
        )
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let route = RideRoute(name: "Saved route", createdAt: date, segments: [])

        try await repository.save(route)
        try await repository.saveDraft(route)

        #expect(await repository.loadRoutes() == [route])
        #expect(await repository.loadDraft() == route)

        try await repository.saveDraft(nil)
        #expect(await repository.loadDraft() == nil)
    }
}
