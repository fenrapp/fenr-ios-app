import Foundation
import Testing
@testable import WatchCompanionData
import WatchCompanionDomain

struct CompanionSnapshotCodecTests {
    @Test func roundTripPreservesTelemetryAgeAndUnavailableFields() throws {
        let now = Date()
        let snapshot = CompanionSnapshot(
            generatedAt: now, telemetryAt: now.addingTimeInterval(-30),
            bikeConnected: true, batteryPercent: 38, mapIndex: 4
        )
        let codec = CompanionSnapshotCodec(encoder: JSONEncoder(), decoder: JSONDecoder())
        let data = try codec.encode(snapshot)
        #expect(try codec.decode(data) == snapshot)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["vin"] == nil && object["pin"] == nil)
        #expect(object["tractionPercent"] == nil)
    }

    @Test func delayedContextCannotReplaceNewerLiveReply() {
        let now = Date()
        let codec = CompanionSnapshotCodec(encoder: JSONEncoder(), decoder: JSONDecoder())
        let latest = CompanionSnapshot(generatedAt: now, batteryPercent: 50)
        let delayed = CompanionSnapshot(generatedAt: now.addingTimeInterval(-10), batteryPercent: 49)
        #expect(!codec.accepts(delayed, after: latest))
        #expect(!codec.accepts(latest, after: latest))
        #expect(codec.accepts(latest, after: delayed))
        #expect(codec.accepts(delayed, after: nil))
    }

    @Test func incompatibleOrCorruptPayloadsAreRejected() throws {
        let codec = CompanionSnapshotCodec(encoder: JSONEncoder(), decoder: JSONDecoder())
        let data = try codec.encode(.init(generatedAt: Date()))
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["version"] = 999
        let futureVersion = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: (any Error).self) { try codec.decode(futureVersion) }
        #expect(throws: (any Error).self) { try codec.decode(Data(repeating: 0, count: 20_000)) }
        let invalidPercent = try codec.encode(.init(generatedAt: Date(), batteryPercent: 150))
        #expect(throws: (any Error).self) { try codec.decode(invalidPercent) }
    }
}
