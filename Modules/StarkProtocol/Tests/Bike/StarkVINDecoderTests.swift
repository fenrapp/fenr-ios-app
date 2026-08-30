import Foundation
import StarkProtocol
import Testing

@Suite("Stark VIN decoder")
struct StarkVINDecoderTests {
    @Test("VIN decoder trims null padding and whitespace")
    func vinDecode() throws {
        let payload = try StarkVINDecoder().decode(StarkProtocolFixtures.vinPadded)

        #expect(payload.value == StarkProtocolFixtures.referenceVIN)
    }

    @Test("Empty VIN payload reports required length")
    func emptyVINPayload() {
        #expect(throws: StarkProtocolError.payloadTooShort(expected: 1, actual: 0)) {
            try StarkVINDecoder().decode(Data())
        }
    }
}
