@testable import BLETraceData
import BLETraceDomain
import Foundation
import Testing

@Suite("BLE trace record codec")
struct BLETraceRecordCodecTests {
    private let codec = BLETraceRecordCodec(
        lineEncoder: BLETraceJSONLineEncoder(),
        boundaryDecoder: .init()
    )
    private let sessionID = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!

    @Test("Encodes the schema-one header as exact JSONL bytes")
    func encodesHeader() throws {
        let context = BLETraceSessionContext(
            id: sessionID,
            startedAt: Date(timeIntervalSince1970: 10.123),
            startUptimeNanoseconds: 10_000_000_000,
            reason: .connectionRequest
        )
        let environment = BLETraceEnvironment(
            appVersion: "1.2/3",
            appBuild: "42",
            operatingSystem: "iOS 26.5",
            deviceModel: "iPhone/Test"
        )

        let data = try codec.encodeHeader(context: context, environment: environment)

        let expected = #"{"app_build":"42","app_version":"1.2/3","device_model":"iPhone/Test","#
            + #""operating_system":"iOS 26.5","#
            + #""privacy_policy":"vin_peripheral_and_authentication_redacted","#
            + #""record_type":"header","schema_version":1,"#
            + #""session_id":"00000000-0000-0000-0000-000000000101","#
            + #""start_reason":"connection_request","started_at":"1970-01-01T00:00:10.123Z"}"#
        #expect(data == line(expected))
    }

    @Test("Encodes a complete event as exact JSONL bytes")
    func encodesEvent() throws {
        let event = BLETraceEvent(
            timestamp: Date(timeIntervalSince1970: 11.25),
            uptimeNanoseconds: 10_002_345_678,
            category: "gatt/test",
            operation: .valueUpdated,
            direction: .inbound,
            serviceUUID: "SERVICE/1",
            characteristicUUID: "CHAR/1",
            characteristicProperties: "read,notify",
            byteCount: 2,
            payloadHex: "AA/BB",
            payloadRedacted: false,
            decodeStatus: .decoded,
            readPending: true,
            detail: "path/a",
            error: BLETraceError(domain: "test", code: 7, detail: "oops/a")
        )

        let data = try codec.encodeEvent(
            event,
            sessionID: sessionID,
            sequence: 3,
            startUptimeNanoseconds: 10_000_000_000
        )

        let expected = #"{"byte_count":2,"category":"gatt/test","characteristic_properties":"read,notify","#
            + #""characteristic_uuid":"CHAR/1","decode_status":"decoded","detail":"path/a","#
            + #""direction":"inbound","elapsed_ms":2,"#
            + #""error":{"code":7,"detail":"oops/a","domain":"test"},"#
            + #""operation":"value_updated","payload_hex":"AA/BB","payload_redacted":false,"#
            + #""read_pending":true,"record_type":"event","schema_version":1,"sequence":3,"#
            + #""service_uuid":"SERVICE/1","#
            + #""session_id":"00000000-0000-0000-0000-000000000101","#
            + #""timestamp":"1970-01-01T00:00:11.250Z"}"#
        #expect(data == line(expected))
    }

    @Test("Omits optional values, redacts payload, and clamps elapsed time")
    func encodesRedactedEventWithClampedElapsedTime() throws {
        let event = BLETraceEvent(
            timestamp: Date(timeIntervalSince1970: 9),
            uptimeNanoseconds: 9_999_999_999,
            category: "privacy",
            operation: .error,
            direction: .internalEvent,
            payloadHex: "SHOULD_NOT_APPEAR",
            payloadRedacted: true
        )

        let data = try codec.encodeEvent(
            event,
            sessionID: sessionID,
            sequence: 1,
            startUptimeNanoseconds: 10_000_000_000
        )

        let expected = #"{"category":"privacy","direction":"internal","elapsed_ms":0,"operation":"error","#
            + #""payload_redacted":true,"record_type":"event","schema_version":1,"sequence":1,"#
            + #""session_id":"00000000-0000-0000-0000-000000000101","#
            + #""timestamp":"1970-01-01T00:00:09.000Z"}"#
        #expect(data == line(expected))
    }

    @Test("Encodes the fixed storage-limit marker as exact JSONL bytes")
    func encodesStorageLimitMarker() throws {
        let data = try codec.encodeStorageLimitMarker(
            sessionID: sessionID,
            sequence: 9,
            timestamp: Date(timeIntervalSince1970: 12.5),
            uptimeNanoseconds: 10_250_999_999,
            startUptimeNanoseconds: 10_000_000_000
        )

        let expected = #"{"category":"storage","#
            + #""detail":"Trace stopped after reaching the configured storage limit","#
            + #""direction":"internal","elapsed_ms":250,"operation":"capture_truncated","#
            + #""payload_redacted":false,"record_type":"event","schema_version":1,"sequence":9,"#
            + #""session_id":"00000000-0000-0000-0000-000000000101","#
            + #""timestamp":"1970-01-01T00:00:12.500Z"}"#
        #expect(data == line(expected))
    }

    @Test("Encodes a fixed-point footer as exact JSONL bytes")
    func encodesFooter() throws {
        let data = try codec.encodeFooter(BLETraceRecordCodec.FooterInput(
            sessionID: sessionID,
            endedAt: Date(timeIntervalSince1970: 12.123),
            durationMilliseconds: 2_123,
            eventCount: 4,
            baseBytes: 100,
            status: .complete,
            reason: .userDisconnected
        ))

        let expected = #"{"bytes":330,"duration_ms":2123,"ended_at":"1970-01-01T00:00:12.123Z","#
            + #""event_count":4,"reason":"user_disconnected","record_type":"footer","schema_version":1,"#
            + #""session_id":"00000000-0000-0000-0000-000000000101","status":"complete"}"#
        #expect(data == line(expected))
        #expect(100 + data.count == 330)
    }

    @Test("Decodes valid header and session boundaries")
    func decodesValidBoundaries() throws {
        let header = data(headerBoundaryJSON)
        let footer = data(footerBoundaryJSON(status: "truncated"))

        #expect(codec.decodeHeaderBoundary(header) == BLETraceRecordCodec.HeaderBoundary(
            sessionID: sessionID,
            startedAt: Date(timeIntervalSince1970: 10)
        ))
        #expect(codec.decodeSessionBoundary(
            headerData: header,
            footerData: footer
        ) == BLETraceRecordCodec.SessionBoundary(
            sessionID: sessionID,
            startedAt: Date(timeIntervalSince1970: 10),
            endedAt: Date(timeIntervalSince1970: 70),
            eventCount: 3,
            status: .truncated
        ))
    }

    @Test("Rejects invalid header boundaries")
    func rejectsInvalidHeaders() {
        let valid = headerBoundaryJSON
        let invalidHeaders = [
            valid.replacingOccurrences(of: #""header""#, with: #""event""#),
            valid.replacingOccurrences(of: #""schema_version":1"#, with: #""schema_version":2"#),
            valid.replacingOccurrences(of: #""1970-01-01T00:00:10.000Z""#, with: #""invalid""#),
            "not-json"
        ]

        for header in invalidHeaders {
            #expect(codec.decodeHeaderBoundary(data(header)) == nil)
        }
    }

    @Test("Rejects invalid session boundaries")
    func rejectsInvalidSessionBoundaries() {
        let header = data(headerBoundaryJSON)
        let valid = footerBoundaryJSON(status: "complete")
        let invalidFooters = [
            valid.replacingOccurrences(of: #""footer""#, with: #""event""#),
            valid.replacingOccurrences(of: #""schema_version":1"#, with: #""schema_version":2"#),
            valid.replacingOccurrences(of: "000000000101", with: "000000000102"),
            valid.replacingOccurrences(of: #""1970-01-01T00:01:10.000Z""#, with: #""invalid""#),
            valid.replacingOccurrences(of: "00:01:10", with: "00:00:09"),
            valid.replacingOccurrences(of: #""event_count":3"#, with: #""event_count":-1"#),
            valid.replacingOccurrences(of: #""complete""#, with: #""unknown""#)
        ]

        for footer in invalidFooters {
            #expect(codec.decodeSessionBoundary(
                headerData: header,
                footerData: data(footer)
            ) == nil)
        }
    }

    private func line(_ value: String) -> Data {
        data(value + "\n")
    }

    private func data(_ value: String) -> Data {
        Data(value.utf8)
    }

    private var headerBoundaryJSON: String {
        #"{"record_type":"header","schema_version":1,"#
            + #""session_id":"00000000-0000-0000-0000-000000000101","#
            + #""started_at":"1970-01-01T00:00:10.000Z"}"#
    }

    private func footerBoundaryJSON(status: String) -> String {
        #"{"ended_at":"1970-01-01T00:01:10.000Z","event_count":3,"record_type":"footer","#
            + #""schema_version":1,"session_id":"00000000-0000-0000-0000-000000000101","#
            + #""status":"\#(status)"}"#
    }
}
