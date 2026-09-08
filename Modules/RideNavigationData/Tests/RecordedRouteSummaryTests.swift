import Foundation
@testable import RideNavigationData
import RideNavigationDomain
import Testing

@MainActor
struct RecordedRouteSummaryTests {
    @Test("Existing sidecars with obsolete point and segment counts remain readable without loading geometry")
    func obsoleteSummaryFieldsRemainCompatible() async throws {
        let directory = try TemporaryRouteDirectory()
        let writer = RouteSummaryRepositoryTestFactory.make(directory: directory, codec: StoredRideRouteCodec())
        let route = RideNavigationDataFixtures.makeRoute()
        try await writer.save(route)
        let url = await writer.summaryURL(id: route.id)
        var stored = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        var summary = try #require(stored["summary"] as? [String: Any])
        summary["pointCount"] = route.points.count
        summary["segmentCount"] = route.segments.count
        stored["summary"] = summary
        try JSONSerialization.data(withJSONObject: stored).write(to: url)

        let codec = CountingStoredRideRouteCodec(base: StoredRideRouteCodec())
        let reader = RouteSummaryRepositoryTestFactory.make(directory: directory, codec: codec)
        #expect(await reader.loadRouteSummaries() == [RideRouteSummary(route)])
        #expect(codec.decodeCount == 0)
    }

    @Test("An external replacement between saving and fingerprinting cannot acquire the previous route's summary")
    func replacementDuringSaveDoesNotPoisonSummary() async throws {
        let directory = try TemporaryRouteDirectory()
        let original = RideNavigationDataFixtures.makeRoute(name: "Original")
        let replacement = original.renamed("Replacement", at: original.updatedAt.addingTimeInterval(10))
        let writer = try RouteSummaryRepositoryTestFactory.makeReplacingRouteAfterSave(
            directory: directory, replacement: replacement, codec: StoredRideRouteCodec()
        )

        try await writer.save(original)

        #expect(try await writer.loadRoute(id: original.id) == replacement)
        #expect(await writer.loadRouteSummaries() == [RideRouteSummary(replacement)])
        let reopened = RouteSummaryRepositoryTestFactory.make(directory: directory, codec: StoredRideRouteCodec())
        #expect(await reopened.loadRouteSummaries() == [RideRouteSummary(replacement)])
        #expect(try await reopened.loadRoute(id: original.id) == replacement)
    }

    @Test("One hundred large routes load metadata without decoding any geometry, including after relaunch")
    func largeLibraryLoadsOnlySummaries() async throws {
        let directory = try TemporaryRouteDirectory()
        let writer = RouteSummaryRepositoryTestFactory.make(directory: directory, codec: StoredRideRouteCodec())
        let segment = RideRouteSegment(points: LargeRouteLibraryFixture.points(count: 10_000))
        var ids: [UUID] = []
        for index in 0 ..< 100 {
            let route = RideRoute(
                name: "Route \(index)", createdAt: Date(timeIntervalSince1970: 1), segments: [segment]
            )
            ids.append(route.id)
            try await writer.save(route)
        }
        let codec = CountingStoredRideRouteCodec(base: StoredRideRouteCodec())
        let reader = RouteSummaryRepositoryTestFactory.make(directory: directory, codec: codec)
        let summaries = await reader.loadRouteSummaries()
        #expect(summaries.count == 100)
        #expect(Set(summaries.map(\.id)) == Set(ids))
        #expect(codec.decodeCount == 0)
        #expect(await reader.loadRouteSummaries() == summaries)
        #expect(codec.decodeCount == 0)
        let first = try #require(summaries.first)
        let selected = try #require(try await reader.loadRoute(id: first.id))
        #expect(selected.segments.first?.points == segment.points)
        #expect(selected.distanceMeters == first.distanceMeters)
        #expect(codec.decodeCount == 1)
        let sidecarURL = await reader.summaryURL(id: first.id)
        #expect(try Data(contentsOf: sidecarURL).count < 1_024)
    }

    @Test("Legacy geometry is decoded once and remains byte-for-byte unchanged")
    func repairsLegacyMetadataWithoutRewritingGeometry() async throws {
        let directory = try TemporaryRouteDirectory()
        let route = try StoredRideRouteCodec().decode(StoredRideRouteFixtures.legacyRouteData)
        let url = directory.routeURL(id: route.id)
        try StoredRideRouteFixtures.legacyRouteData.write(to: url)
        let codec = CountingStoredRideRouteCodec(base: StoredRideRouteCodec())
        let reader = RouteSummaryRepositoryTestFactory.make(directory: directory, codec: codec)
        #expect(await reader.loadRouteSummaries() == [RideRouteSummary(route)])
        #expect(codec.decodeCount == 1)
        let reopened = RouteSummaryRepositoryTestFactory.make(directory: directory, codec: codec)
        #expect(await reopened.loadRouteSummaries() == [RideRouteSummary(route)])
        #expect(codec.decodeCount == 1)
        #expect(try Data(contentsOf: url) == StoredRideRouteFixtures.legacyRouteData)
        #expect(try await reopened.loadRoute(id: route.id) == route)
    }

    @Test("Same-size atomic replacement with preserved modification date invalidates disk and memory summaries")
    func replacementInvalidatesSummary() async throws {
        let directory = try TemporaryRouteDirectory()
        let codec = CountingStoredRideRouteCodec(base: StoredRideRouteCodec())
        let reader = RouteSummaryRepositoryTestFactory.make(directory: directory, codec: codec)
        let old = RideNavigationDataFixtures.makeRoute(name: "Alpha")
        try await reader.save(old)
        #expect(await reader.loadRouteSummaries().first?.name == "Alpha")
        let url = directory.routeURL(id: old.id)
        let date = try #require(FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date)
        let oldData = try Data(contentsOf: url)
        let newData = try StoredRideRouteCodec().encode(old.renamed("Bravo", at: old.updatedAt))
        #expect(oldData.count == newData.count)
        try newData.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
        #expect(await reader.loadRouteSummaries().first?.name == "Bravo")
        #expect(codec.decodeCount == 1)
        let reopened = RouteSummaryRepositoryTestFactory.make(directory: directory, codec: codec)
        #expect(await reopened.loadRouteSummaries().first?.name == "Bravo")
        #expect(codec.decodeCount == 1)
        try FileManager.default.removeItem(at: url)
        #expect(await reader.loadRouteSummaries().isEmpty)
        #expect(try await reader.loadRoute(id: old.id) == nil)
    }

    @Test("Sidecar failures cannot turn an atomically saved route into a failed save")
    func derivedWriteFailurePreservesConfirmedRoute() async throws {
        let directory = try TemporaryRouteDirectory()
        let repository = RouteSummaryRepositoryTestFactory.make(directory: directory, codec: StoredRideRouteCodec())
        let route = RideNavigationDataFixtures.makeRoute()
        let summaryURL = await repository.summaryURL(id: route.id)
        try FileManager.default.createDirectory(at: summaryURL, withIntermediateDirectories: true)
        try await repository.save(route)
        let reopened = RouteSummaryRepositoryTestFactory.make(directory: directory, codec: StoredRideRouteCodec())
        #expect(await reopened.loadRouteSummaries() == [RideRouteSummary(route)])
        #expect(try await reopened.loadRoute(id: route.id) == route)
        try await reopened.delete(id: route.id)
        #expect(await repository.loadRouteSummaries().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: summaryURL.path))
    }

    @Test("Corrupt sidecars are repaired; corrupt geometry produces an explicit detail error")
    func corruptionRemainsHonest() async throws {
        let directory = try TemporaryRouteDirectory()
        let writer = RouteSummaryRepositoryTestFactory.make(directory: directory, codec: StoredRideRouteCodec())
        let route = RideNavigationDataFixtures.makeRoute()
        try await writer.save(route)
        let summaryURL = await writer.summaryURL(id: route.id)
        try Data("invalid".utf8).write(to: summaryURL)
        let codec = CountingStoredRideRouteCodec(base: StoredRideRouteCodec())
        let reader = RouteSummaryRepositoryTestFactory.make(directory: directory, codec: codec)
        #expect(await reader.loadRouteSummaries() == [RideRouteSummary(route)])
        #expect(codec.decodeCount == 1)
        try Data("invalid geometry".utf8).write(to: directory.routeURL(id: route.id), options: .atomic)
        await #expect(throws: (any Error).self) { try await reader.loadRoute(id: route.id) }
        #expect(await reader.loadRouteSummaries().isEmpty)
    }

    @Test("Canceled summary and detail loads leave a valid legacy route and its missing sidecar untouched")
    func canceledReadsDoNotDecodeOrCacheValidGeometry() async throws {
        let directory = try TemporaryRouteDirectory()
        let route = RideNavigationDataFixtures.makeRoute()
        let data = try StoredRideRouteCodec().encode(route)
        let routeURL = directory.routeURL(id: route.id)
        try data.write(to: routeURL)
        let codec = CountingStoredRideRouteCodec(base: StoredRideRouteCodec())
        let reader = RouteSummaryRepositoryTestFactory.make(directory: directory, codec: codec)
        let summaryURL = await reader.summaryURL(id: route.id)

        let gate = DeterministicAsyncGate()
        let task = Task {
            await gate.wait()
            return await reader.loadRouteSummaries()
        }
        #expect(await gate.waitUntilBlocked())
        task.cancel()
        await gate.open()
        #expect(await task.value.isEmpty)

        let detailGate = DeterministicAsyncGate()
        let detailTask = Task {
            await detailGate.wait()
            return try await reader.loadRoute(id: route.id)
        }
        #expect(await detailGate.waitUntilBlocked())
        detailTask.cancel()
        await detailGate.open()
        await #expect(throws: CancellationError.self) { try await detailTask.value }

        #expect(codec.decodeCount == 0)
        #expect(!FileManager.default.fileExists(atPath: summaryURL.path))
        #expect(try Data(contentsOf: routeURL) == data)
        #expect(await reader.loadRouteSummaries() == [RideRouteSummary(route)])
        #expect(codec.decodeCount == 1)
    }
}
