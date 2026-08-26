import Foundation
import StarkProtocol
import Testing

@Suite("Stark live estimations decoder")
struct StarkLiveEstimationsDecoderTests {
    @Test("Estimations preserve unsigned estimates and signed native power")
    func estimations() throws {
        let payload = try StarkLiveEstimationsDecoder().decode(
            StarkProtocolFixtures.liveEstimationsNegativePower
        )

        #expect(payload.estimatedRangeRaw == 0x1234)
        #expect(payload.estimatedTimeRaw == 0x5678)
        #expect(payload.nativeMotorPowerRaw == -100)
    }

    @Test("Estimations reject short data")
    func shortPayload() {
        #expect(throws: StarkProtocolError.payloadTooShort(
            expected: StarkLiveEstimationsPayloadLayout.requiredLength,
            actual: 2
        )) {
            try StarkLiveEstimationsDecoder().decode(StarkProtocolFixtures.invalidTwoBytes)
        }
    }
}
