import Foundation
import StarkProtocol
import Testing

@Suite("Stark battery electrical decoders")
struct StarkBatteryElectricalDecoderTests {
    @Test("Battery parameters preserve series, parallel and capacity raw")
    func batteryParameters() throws {
        let payload = try StarkBatteryParametersDecoder().decode(StarkProtocolFixtures.batteryParameters)

        #expect(payload.seriesCount == 100)
        #expect(payload.parallelCount == 2)
        #expect(payload.capacityRaw == 0x1234)
    }

    @Test("Battery signals decode both BMS blocks and signed current")
    func batterySignals() throws {
        let payload = try StarkBatterySignalsDecoder().decode(
            StarkProtocolFixtures.batterySignalsNegativeCurrent
        )

        #expect(payload.positive.dcBusRaw == 4_000)
        #expect(payload.positive.temperatureRaw == 2_534)
        #expect(payload.positive.humidityRaw == 5_012)
        #expect(payload.positive.controlFlags == 0x1234)
        #expect(payload.negative.dcBusRaw == 3_995)
        #expect(payload.negative.temperatureRaw == 2_450)
        #expect(payload.negative.humidityRaw == 4_899)
        #expect(payload.negative.controlFlags == 0xABCD)
        #expect(payload.currentRaw == -25)
        #expect(payload.currentAmperes == -25)
        #expect(payload.positive.dcBusVolts == 400)
        #expect(payload.positive.temperatureCelsius == 25.34)
        #expect(payload.positive.humidityPercent == 50.12)
    }

    @Test("Battery electrical payloads reject short data")
    func shortPayloads() {
        #expect(throws: StarkProtocolError.payloadTooShort(
            expected: StarkBatteryParametersPayloadLayout.requiredLength,
            actual: 2
        )) {
            try StarkBatteryParametersDecoder().decode(StarkProtocolFixtures.invalidTwoBytes)
        }
        #expect(throws: StarkProtocolError.payloadTooShort(
            expected: StarkBatterySignalsPayloadLayout.requiredLength,
            actual: 2
        )) {
            try StarkBatterySignalsDecoder().decode(StarkProtocolFixtures.invalidTwoBytes)
        }
    }
}
