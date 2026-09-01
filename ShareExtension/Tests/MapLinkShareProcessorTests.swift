import Foundation
import RideNavigationDomain
import Testing

@MainActor
@Suite("Map link share processor")
struct MapLinkShareProcessorTests {
    @Test("Accepts Apple Maps HTTPS links")
    func acceptsAppleMapsHTTPS() async throws {
        let fixture = try MapLinkShareTestFixture()
        defer { fixture.removeTemporaryFiles() }
        let url = try #require(URL(string: "https://maps.apple.com/?daddr=41,2"))

        try await fixture.processor.process(url: url)

        #expect(await fixture.store.saved().map(\.url) == [url])
    }

    @Test("Accepts Google Maps HTTPS links")
    func acceptsGoogleMapsHTTPS() async throws {
        let fixture = try MapLinkShareTestFixture()
        defer { fixture.removeTemporaryFiles() }
        let url = try #require(URL(string: "https://maps.app.goo.gl/FENRTEST"))

        try await fixture.processor.process(url: url)

        #expect(await fixture.store.saved().map(\.url) == [url])
    }

    @Test("Rejects lookalike hosts and unsupported schemes")
    func rejectsLookalikeHostsAndUnsupportedSchemes() async throws {
        let fixture = try MapLinkShareTestFixture()
        defer { fixture.removeTemporaryFiles() }
        let rejectedURLs = try [
            #require(URL(string: "https://maps.apple.com.example.test/route")),
            #require(URL(string: "https://google.com.example.test/route")),
            #require(URL(string: "http://maps.apple.com/route")),
            #require(URL(string: "ftp://maps.google.com/route")),
            #require(URL(string: "file:///tmp/route.txt"))
        ]

        for url in rejectedURLs {
            await #expect(throws: MapLinkShareError.unsupportedURL) {
                try await fixture.processor.process(url: url)
            }
        }
        #expect(await fixture.store.attempted().isEmpty)
    }

    @Test("Copies a security-scoped directions request into the shared container")
    func copiesSecurityScopedDirectionsRequest() async throws {
        let fixture = try MapLinkShareTestFixture()
        defer { fixture.removeTemporaryFiles() }
        let sourceURL = fixture.rootURL.appendingPathComponent("source.directionsrequest")
        let contents = Data("directions".utf8)
        try contents.write(to: sourceURL)

        try await fixture.processor.process(url: sourceURL)

        let savedURL = try #require(await fixture.store.saved().first?.url)
        #expect(savedURL != sourceURL)
        #expect(savedURL.pathExtension == "directionsrequest")
        #expect(try Data(contentsOf: savedURL) == contents)
        #expect(fixture.securityScope.startedURLs == [sourceURL])
        #expect(fixture.securityScope.stoppedURLs == [sourceURL])
    }

    @Test("Removes a copied directions request when persistence fails")
    func removesCopyOnPersistFailure() async throws {
        let fixture = try MapLinkShareTestFixture(failsOnSave: true)
        defer { fixture.removeTemporaryFiles() }
        let sourceURL = fixture.rootURL.appendingPathComponent("source.directionsrequest")
        try Data("directions".utf8).write(to: sourceURL)

        await #expect(throws: MapLinkShareRecordingStore.Failure.saveFailed) {
            try await fixture.processor.process(url: sourceURL)
        }

        let attemptedURL = try #require(await fixture.store.attempted().first?.url)
        #expect(!FileManager.default.fileExists(atPath: attemptedURL.path))
        #expect(FileManager.default.fileExists(atPath: sourceURL.path))
    }

    @Test("Cancellation does not persist or render a link")
    func cancellationDoesNotPersistOrRender() async throws {
        let fixture = try MapLinkShareTestFixture()
        defer { fixture.removeTemporaryFiles() }
        let gate = MapLinkShareAsyncGate()
        let renderer = MapLinkShareRenderRecorder()
        let url = try #require(URL(string: "https://maps.apple.com/?daddr=41,2"))
        let task = Task {
            await gate.wait()
            try await fixture.processor.process(url: url)
            await renderer.render()
        }
        await gate.waitUntilBlocked()

        task.cancel()
        await gate.open()

        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(await fixture.store.attempted().isEmpty)
        #expect(await renderer.count() == 0)
    }

    @Test("Successful directions request save replaces the prior managed copy")
    func successfulDirectionsRequestSaveReplacesPriorManagedCopy() async throws {
        let fixture = try MapLinkShareTestFixture()
        defer { fixture.removeTemporaryFiles() }
        let priorURL = try fixture.writeFile(
            named: "FENRIncoming-00000000-0000-0000-0000-000000000002.directionsrequest"
        )
        let sourceURL = fixture.rootURL.appendingPathComponent("source.directionsrequest")
        try Data("replacement".utf8).write(to: sourceURL)

        try await fixture.processor.process(url: sourceURL)

        let savedURL = try #require(await fixture.store.pending()?.url)
        #expect(savedURL.lastPathComponent == "FENRIncoming-00000000-0000-0000-0000-000000000001.directionsrequest")
        #expect(FileManager.default.fileExists(atPath: savedURL.path))
        #expect(!FileManager.default.fileExists(atPath: priorURL.path))
    }

    @Test("Failed replacement preserves the prior pending copy and removes the new copy")
    func failedReplacementPreservesPriorPendingCopyAndRemovesNewCopy() async throws {
        let fixture = try MapLinkShareTestFixture(failsOnSave: true)
        defer { fixture.removeTemporaryFiles() }
        let priorURL = try fixture.writeFile(
            named: "FENRIncoming-00000000-0000-0000-0000-000000000002.directionsrequest"
        )
        let pendingLink = IncomingMapLink(
            url: priorURL,
            receivedAt: Date(timeIntervalSince1970: 1)
        )
        await fixture.store.seedPending(pendingLink)
        let sourceURL = fixture.rootURL.appendingPathComponent("source.directionsrequest")
        try Data("replacement".utf8).write(to: sourceURL)

        await #expect(throws: MapLinkShareRecordingStore.Failure.saveFailed) {
            try await fixture.processor.process(url: sourceURL)
        }

        let attemptedURL = try #require(await fixture.store.attempted().first?.url)
        #expect(await fixture.store.pending() == pendingLink)
        #expect(FileManager.default.fileExists(atPath: priorURL.path))
        #expect(!FileManager.default.fileExists(atPath: attemptedURL.path))
    }

    @Test("Successful web save removes managed copies without deleting unowned files")
    func successfulWebSaveRemovesManagedCopiesWithoutDeletingUnownedFiles() async throws {
        let fixture = try MapLinkShareTestFixture()
        defer { fixture.removeTemporaryFiles() }
        let managedURL = try fixture.writeFile(
            named: "FENRIncoming-00000000-0000-0000-0000-000000000002.directionsrequest"
        )
        let unownedURL = try fixture.writeFile(named: "SharedRoute.directionsrequest")
        let wrongExtensionURL = try fixture.writeFile(
            named: "FENRIncoming-00000000-0000-0000-0000-000000000003.txt"
        )
        let webURL = try #require(URL(string: "https://maps.apple.com/?daddr=41,2"))

        try await fixture.processor.process(url: webURL)

        #expect(await fixture.store.pending()?.url == webURL)
        #expect(!FileManager.default.fileExists(atPath: managedURL.path))
        #expect(FileManager.default.fileExists(atPath: unownedURL.path))
        #expect(FileManager.default.fileExists(atPath: wrongExtensionURL.path))
    }
}
