import BLETraceData
import BLETraceDomain
import Foundation
import Testing

@Suite("BLE trace privacy")
struct FileBLETraceLogRepositoryPrivacyTests {
    @Test("Redaction always removes payload while preserving opaque UUID fields")
    func enforcesContradictoryPayloadRedaction() async throws {
        let context = try makeBLETraceDataTestContext()
        defer { try? FileManager.default.removeItem(at: context.directory.deletingLastPathComponent()) }
        let session = BLETraceDataFixtures.session()
        let serviceUUID = "11111111-2222-3333-4444-555555555555"
        let characteristicUUID = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
        await context.repository.startSession(session)
        await context.repository.record(BLETraceDataFixtures.event(
            index: 1,
            payloadHex: "PRIVATE",
            payloadRedacted: true,
            serviceUUID: serviceUUID,
            characteristicUUID: characteristicUUID
        ))
        await context.repository.finishSession(reason: .userDisconnected)

        let export = try await context.repository.prepareExport(sessionID: session.id)
        let event = try #require(traceRecords(at: export).first {
            $0["record_type"] as? String == "event"
        })
        #expect(event["payload_redacted"] as? Bool == true)
        #expect(event["payload_hex"] == nil || event["payload_hex"] is NSNull)
        #expect(event["service_uuid"] as? String == serviceUUID)
        #expect(event["characteristic_uuid"] as? String == characteristicUUID)
    }
}
