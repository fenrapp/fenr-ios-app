import Foundation
@testable import RideNavigationData
import RideNavigationDomain
import Testing

@MainActor
@Suite("File recorded route repository")
struct FileRecordedRouteRepositoryTests {
    @Test("Persists protected routes and manages delete plus draft lifecycle")
    func managesRouteAndDraftLifecycle() async throws {
        let directory = try TemporaryRouteDirectory()
        let repository = makeRepository(directory: directory)
        let route = RideNavigationDataFixtures.makeRoute()

        try await repository.save(route)
        try await repository.saveDraft(route)

        #expect(await repository.loadRouteSummaries() == [RideRouteSummary(route)])
        #expect(try await repository.loadRoute(id: route.id) == route)
        #expect(await repository.loadDraft() == route)
        let routeAttributes = try FileManager.default.attributesOfItem(
            atPath: directory.routeURL(id: route.id).path
        )
        let draftAttributes = try FileManager.default.attributesOfItem(
            atPath: directory.draftURL.path
        )
        #expect(FileRecordedRouteRepository.writeOptions.contains(.atomic))
        #expect(FileRecordedRouteRepository.writeOptions.contains(
            .completeFileProtectionUntilFirstUserAuthentication
        ))
        if let routeProtection = routeAttributes[.protectionKey] as? FileProtectionType {
            #expect(routeProtection == .completeUntilFirstUserAuthentication)
        }
        if let draftProtection = draftAttributes[.protectionKey] as? FileProtectionType {
            #expect(draftProtection == .completeUntilFirstUserAuthentication)
        }

        try await repository.delete(id: route.id)
        try await repository.saveDraft(nil)
        #expect(await repository.loadRouteSummaries().isEmpty)
        #expect(try await repository.loadRoute(id: route.id) == nil)
        #expect(await repository.loadDraft() == nil)
        #expect(!FileManager.default.fileExists(atPath: directory.routeURL(id: route.id).path))
        #expect(!FileManager.default.fileExists(atPath: directory.draftURL.path))
    }

    @Test("Omits corrupt and filename-mismatched routes while retaining valid data")
    func omitsInvalidRouteFiles() async throws {
        let directory = try TemporaryRouteDirectory()
        let repository = makeRepository(directory: directory)
        let valid = RideNavigationDataFixtures.makeRoute()
        try await repository.save(valid)

        let corruptID = UUID()
        try Data("not-json".utf8).write(to: directory.routeURL(id: corruptID))
        let mismatched = RideNavigationDataFixtures.makeRoute(id: UUID())
        try StoredRideRouteCodec().encode(mismatched).write(to: directory.routeURL(id: UUID()))

        #expect(await repository.loadRouteSummaries() == [RideRouteSummary(valid)])
        #expect(try await repository.loadRoute(id: valid.id) == valid)
    }

    @Test("Sorts routes by updated date, created date, then UUID")
    func loadsRoutesInStableOrder() async throws {
        let directory = try TemporaryRouteDirectory()
        let repository = makeRepository(directory: directory)
        let date100 = Date(timeIntervalSince1970: 100)
        let date200 = Date(timeIntervalSince1970: 200)
        let date300 = Date(timeIntervalSince1970: 300)
        let first = RideNavigationDataFixtures.makeRoute(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            createdAt: date100,
            updatedAt: date300
        )
        let second = RideNavigationDataFixtures.makeRoute(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            createdAt: date200,
            updatedAt: date200
        )
        let third = RideNavigationDataFixtures.makeRoute(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            createdAt: date100,
            updatedAt: date200
        )
        let fourth = RideNavigationDataFixtures.makeRoute(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
            createdAt: date100,
            updatedAt: date200
        )
        for route in [fourth, third, second, first] {
            try await repository.save(route)
        }

        #expect(await repository.loadRouteSummaries().map(\.id) == [
            first.id,
            second.id,
            third.id,
            fourth.id
        ])
    }

    @Test("Canceled save, delete, and draft operations do not mutate storage")
    func canceledMutationsDoNotChangeStorage() async throws {
        let directory = try TemporaryRouteDirectory()
        let repository = makeRepository(directory: directory)
        let saved = RideNavigationDataFixtures.makeRoute()
        let unsaved = RideNavigationDataFixtures.makeRoute(id: UUID(), name: "Unsaved")
        let replacementDraft = RideNavigationDataFixtures.makeRoute(id: UUID(), name: "Replacement")
        try await repository.save(saved)
        try await repository.saveDraft(saved)

        let saveGate = DeterministicAsyncGate()
        let saveTask = Task {
            await saveGate.wait()
            try await repository.save(unsaved)
        }
        #expect(await saveGate.waitUntilBlocked())
        saveTask.cancel()
        await saveGate.open()
        await #expect(throws: CancellationError.self) { try await saveTask.value }

        let deleteGate = DeterministicAsyncGate()
        let deleteTask = Task {
            await deleteGate.wait()
            try await repository.delete(id: saved.id)
        }
        #expect(await deleteGate.waitUntilBlocked())
        deleteTask.cancel()
        await deleteGate.open()
        await #expect(throws: CancellationError.self) { try await deleteTask.value }

        let draftGate = DeterministicAsyncGate()
        let draftTask = Task {
            await draftGate.wait()
            try await repository.saveDraft(replacementDraft)
        }
        #expect(await draftGate.waitUntilBlocked())
        draftTask.cancel()
        await draftGate.open()
        await #expect(throws: CancellationError.self) { try await draftTask.value }

        #expect(await repository.loadRouteSummaries() == [RideRouteSummary(saved)])
        #expect(try await repository.loadRoute(id: saved.id) == saved)
        #expect(await repository.loadDraft() == saved)
        #expect(!FileManager.default.fileExists(atPath: directory.routeURL(id: unsaved.id).path))
    }

    @Test("Canceled loads return no partially loaded state")
    func canceledLoadsReturnNoState() async throws {
        let directory = try TemporaryRouteDirectory()
        let repository = makeRepository(directory: directory)
        let route = RideNavigationDataFixtures.makeRoute()
        try await repository.save(route)
        try await repository.saveDraft(route)

        let routesGate = DeterministicAsyncGate()
        let routesTask = Task {
            await routesGate.wait()
            return await repository.loadRouteSummaries()
        }
        #expect(await routesGate.waitUntilBlocked())
        routesTask.cancel()
        await routesGate.open()

        let draftGate = DeterministicAsyncGate()
        let draftTask = Task {
            await draftGate.wait()
            return await repository.loadDraft()
        }
        #expect(await draftGate.waitUntilBlocked())
        draftTask.cancel()
        await draftGate.open()

        #expect(await routesTask.value.isEmpty)
        #expect(await draftTask.value == nil)
    }

    private func makeRepository(
        directory: TemporaryRouteDirectory
    ) -> FileRecordedRouteRepository {
        FileRecordedRouteRepository(
            fileManager: FileManager(),
            directoryURL: directory.url,
            codec: StoredRideRouteCodec()
        )
    }
}
