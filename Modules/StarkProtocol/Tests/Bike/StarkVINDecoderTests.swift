import StarkProtocol
import Testing

@Suite("Stark VIN decoder")
struct StarkVINDecoderTests {
    @Test("VIN decoder trims null padding and whitespace")
    func vinDecode() throws {
        let payload = try StarkVINDecoder().decode(StarkProtocolFixtures.vinPadded)

        #expect(payload.value == StarkProtocolFixtures.referenceVIN)
    }
}
