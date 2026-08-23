import Foundation
import StarkProtocol
import Testing

@Suite("Stark battery capture decoder")
struct StarkBatteryCaptureDecoderTests {
    private let decoder = StarkBatteryCaptureDecoder()

    @Test("Raw capture preserves every observed byte")
    func preservesObservedBytes() throws {
        let bytes = Data([0xAA, 0xBB, 0xCC])

        let payload = try decoder.decode(bytes)

        #expect(payload.bytes == bytes)
    }

    @Test("Empty capture is rejected")
    func rejectsEmptyPayload() {
        #expect(throws: StarkProtocolError.payloadTooShort(expected: 1, actual: 0)) {
            try decoder.decode(Data())
        }
    }
}
