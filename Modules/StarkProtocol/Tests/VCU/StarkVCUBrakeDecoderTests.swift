import StarkProtocol
import Testing

@Suite("Stark VCU brake decoder")
struct StarkVCUBrakeDecoderTests {
    private let decoder = StarkVCUBrakeDecoder()

    @Test("VCU telemetry decodes inactive brake signals")
    func inactiveBrake() throws {
        let payload = try decoder.decode(StarkProtocolFixtures.vcuBrakeInactive)

        #expect(payload.primaryBrakeSignal == 0)
        #expect(payload.secondaryBrakeSignal == 0)
        #expect(!payload.isBrakeActive)
    }

    @Test("VCU telemetry decodes active brake signals")
    func activeBrake() throws {
        let payload = try decoder.decode(StarkProtocolFixtures.vcuBrakeActive)

        #expect(payload.primaryBrakeSignal == 1)
        #expect(payload.secondaryBrakeSignal == 1)
        #expect(payload.isBrakeActive)
    }

    @Test("Short VCU telemetry reports required length")
    func invalidPayload() {
        #expect(throws: StarkProtocolError.payloadTooShort(
            expected: StarkVCUBrakePayloadLayout.minimumLength,
            actual: StarkProtocolFixtures.invalidTwoBytes.count
        )) {
            try decoder.decode(StarkProtocolFixtures.invalidTwoBytes)
        }
    }
}
