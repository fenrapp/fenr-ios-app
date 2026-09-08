import Foundation
@testable import RideNavigationData
import RideNavigationDomain
import Testing

@MainActor
@Suite("UserDefaults incoming map link store")
struct UserDefaultsIncomingMapLinkStoreTests {
    @Test("consumes a shared map link exactly once")
    func consumesLinkOnce() async throws {
        let suiteName = "fenr-map-link-tests-\(UUID().uuidString)"
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsIncomingMapLinkStore(
            userDefaults: makeDefaults(suiteName: suiteName),
            encoder: JSONEncoder(),
            decoder: JSONDecoder()
        )
        let link = IncomingMapLink(
            url: try #require(URL(string: "https://maps.apple.com/?daddr=41.0,2.0")),
            receivedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        try await store.save(link)

        let storedData = try #require(
            makeDefaults(suiteName: suiteName).data(forKey: "ride-navigation.pending-map-link")
        )
        #expect(try JSONDecoder().decode(IncomingMapLink.self, from: storedData) == link)
        #expect(try await store.consume() == link)
        #expect(try await store.consume() == nil)
    }

    @Test("discards a malformed payload after reporting the decoding failure")
    func discardsMalformedPayload() async throws {
        let suiteName = "fenr-map-link-tests-\(UUID().uuidString)"
        let key = "malformed-link"
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }
        makeDefaults(suiteName: suiteName).set(Data("not-json".utf8), forKey: key)
        let store = UserDefaultsIncomingMapLinkStore(
            userDefaults: makeDefaults(suiteName: suiteName),
            key: key,
            encoder: JSONEncoder(),
            decoder: JSONDecoder()
        )

        await #expect(throws: DecodingError.self) {
            _ = try await store.consume()
        }
        #expect(try await store.consume() == nil)
    }

    @Test("A canceled save does not replace the pending map link")
    func canceledSaveDoesNotMutate() async throws {
        let suiteName = "fenr-map-link-tests-\(UUID().uuidString)"
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsIncomingMapLinkStore(
            userDefaults: makeDefaults(suiteName: suiteName),
            encoder: JSONEncoder(),
            decoder: JSONDecoder()
        )
        let original = try makeLink(path: "?daddr=41.0,2.0", receivedAt: 1)
        let replacement = try makeLink(path: "?daddr=42.0,3.0", receivedAt: 2)
        try await store.save(original)

        let gate = DeterministicAsyncGate()
        let task = Task {
            await gate.wait()
            try await store.save(replacement)
        }
        #expect(await gate.waitUntilBlocked())
        task.cancel()
        await gate.open()

        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(try await store.consume() == original)
    }

    @Test("A canceled consume leaves the pending map link untouched")
    func canceledConsumeDoesNotMutate() async throws {
        let suiteName = "fenr-map-link-tests-\(UUID().uuidString)"
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsIncomingMapLinkStore(
            userDefaults: makeDefaults(suiteName: suiteName),
            encoder: JSONEncoder(),
            decoder: JSONDecoder()
        )
        let link = try makeLink(path: "?daddr=41.0,2.0", receivedAt: 1)
        try await store.save(link)

        let gate = DeterministicAsyncGate()
        let task = Task {
            await gate.wait()
            return try await store.consume()
        }
        #expect(await gate.waitUntilBlocked())
        task.cancel()
        await gate.open()

        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(try await store.consume() == link)
    }

    private func makeLink(path: String, receivedAt: TimeInterval) throws -> IncomingMapLink {
        IncomingMapLink(
            url: try #require(URL(string: "https://maps.apple.com/\(path)")),
            receivedAt: Date(timeIntervalSince1970: receivedAt)
        )
    }

    nonisolated private func makeDefaults(suiteName: String) -> UserDefaults {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            preconditionFailure("Unable to create isolated UserDefaults suite")
        }
        return defaults
    }
}
