import Foundation
@testable import RideNavigationData
import RideNavigationDomain
import Testing

struct UserDefaultsIncomingMapLinkStoreTests {
    @Test("consumes a shared map link exactly once")
    func consumesLinkOnce() async throws {
        let suiteName = "fenr-map-link-tests-\(UUID().uuidString)"
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }
        let store = try UserDefaultsIncomingMapLinkStore(suiteName: suiteName)
        let link = IncomingMapLink(
            url: try #require(URL(string: "https://maps.apple.com/?daddr=41.0,2.0")),
            receivedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        try await store.save(link)

        #expect(try await store.consume() == link)
        #expect(try await store.consume() == nil)
    }

    @Test("discards a malformed payload after reporting the decoding failure")
    func discardsMalformedPayload() async throws {
        let suiteName = "fenr-map-link-tests-\(UUID().uuidString)"
        let key = "malformed-link"
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.set(Data("not-json".utf8), forKey: key)
        let store = UserDefaultsIncomingMapLinkStore(userDefaults: userDefaults, key: key)

        await #expect(throws: DecodingError.self) {
            _ = try await store.consume()
        }
        #expect(try await store.consume() == nil)
    }
}
