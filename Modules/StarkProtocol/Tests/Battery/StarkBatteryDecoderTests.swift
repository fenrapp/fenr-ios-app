import Foundation
import StarkProtocol
import Testing

@Suite("Stark battery decoder")
struct StarkBatteryDecoderTests {
    private let decoder = StarkBatteryDecoder()

    @Test("Battery decodes SOC, SOH and DC bus")
    func batteryDecode() throws {
        let payload = try decoder.decode(StarkProtocolFixtures.batteryWithDCBus)

        #expect(payload.stateOfChargePercent == 91)
        #expect(payload.stateOfHealthPercent == 99)
        #expect(payload.dcBusRaw == 0x1234)
    }

    @Test("Observed physical payload treats zero SOH as unavailable")
    func observedBatteryDecode() throws {
        let payload = try decoder.decode(StarkProtocolFixtures.observedBatteryWithDCBus)

        #expect(payload.stateOfChargePercent == 76)
        #expect(payload.stateOfHealthPercent == nil)
        #expect(payload.dcBusRaw == 3_948)
    }

    @Test("Minimum payload leaves optional fields unknown")
    func batteryMinimumDecode() throws {
        let payload = try decoder.decode(StarkProtocolFixtures.batteryMinimum)

        #expect(payload.stateOfChargePercent == 91)
        #expect(payload.stateOfHealthPercent == nil)
        #expect(payload.dcBusRaw == nil)
    }

    @Test("Short payload reports required length")
    func invalidPayload() {
        #expect(throws: StarkProtocolError.payloadTooShort(
            expected: StarkBatteryPayloadLayout.minimumLength,
            actual: 0
        )) {
            try decoder.decode(Data())
        }
    }
}
