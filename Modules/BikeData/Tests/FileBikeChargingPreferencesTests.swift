import BikeData
import BikeDomain
import Foundation
import Testing

@MainActor
struct FileBikeChargingPreferencesTests {
    @Test func persistsAcrossInstancesAndSeparatesBikes() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let store = FileBikeChargingPreferencesStore(
            url: url, fileManager: .default, encoder: JSONEncoder(), decoder: JSONDecoder()
        )
        let preferences = BikeChargingPreferences(
            selectedCharger: .standard, pendingTarget: .init(percent: 85, revision: UUID())
        )
        try store.save(preferences, vin: "FENRTEST000000001")
        let reopened = FileBikeChargingPreferencesStore(
            url: url, fileManager: .default, encoder: JSONEncoder(), decoder: JSONDecoder()
        )
        #expect(try reopened.load(vin: "FENRTEST000000001") == preferences)
        #expect(try reopened.load(vin: "FENRTEST000000002") == .init())
    }

    @Test func unreadableDataCannotBeOverwrittenAndStorageFailureThrows() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("invalid".utf8).write(to: url)
        let store = FileBikeChargingPreferencesStore(
            url: url, fileManager: .default, encoder: JSONEncoder(), decoder: JSONDecoder()
        )
        #expect(throws: BikeChargingPreferencesError.self) { try store.load(vin: "FENRTEST000000001") }
        #expect(throws: BikeChargingPreferencesError.self) { try store.save(.init(), vin: "FENRTEST000000001") }
        #expect(try Data(contentsOf: url) == Data("invalid".utf8))
        let blocked = FileBikeChargingPreferencesStore(
            url: url.appendingPathComponent("blocked.json"), fileManager: .default,
            encoder: JSONEncoder(), decoder: JSONDecoder()
        )
        #expect(throws: (any Error).self) { try blocked.save(.init(), vin: "FENRTEST000000001") }
    }

    @Test func rejectsInvalidPendingAndKeepsDemoSeparate() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let live = FileBikeChargingPreferencesStore(
            url: directory.appendingPathComponent("live.json"), fileManager: .default,
            encoder: JSONEncoder(), decoder: JSONDecoder()
        )
        let demo = FileBikeChargingPreferencesStore(
            url: directory.appendingPathComponent("demo.json"), fileManager: .default,
            encoder: JSONEncoder(), decoder: JSONDecoder()
        )
        let pending = BikeChargingPreferences(pendingTarget: .init(percent: 90, revision: UUID()))
        try demo.save(pending, vin: "FENRTEST000000001")
        #expect(try live.load(vin: "FENRTEST000000001") == .init())
        let invalid = BikeChargingPreferences(pendingPower: .init(watts: 7_000, charger: .standard, revision: UUID()))
        #expect(throws: BikeChargingPreferencesError.self) { try live.save(invalid, vin: "FENRTEST000000001") }
    }
}
