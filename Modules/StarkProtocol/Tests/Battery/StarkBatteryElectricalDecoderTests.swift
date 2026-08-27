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

        #expect(payload.positive.voltageCandidateRaw == 409)
        #expect(payload.positive.temperatureRaw == 3_069)
        #expect(payload.positive.humidityRaw == 5_219)
        #expect(payload.positive.controlFlags == 0)
        #expect(payload.negative.voltageCandidateRaw == 405)
        #expect(payload.negative.temperatureRaw == 2_919)
        #expect(payload.negative.humidityRaw == 4_853)
        #expect(payload.negative.controlFlags == 0)
        #expect(payload.currentRaw == -8)
        #expect(payload.currentCandidateAmperes == -8)
        #expect(payload.positive.temperatureCelsius == 30.69)
        #expect(payload.positive.humidityPercent == 52.19)
    }

    @Test("Battery signals preserve a positive current candidate")
    func batterySignalsPositiveCurrent() throws {
        let payload = try StarkBatterySignalsDecoder().decode(
            StarkProtocolFixtures.batterySignalsPositiveCurrent
        )

        #expect(payload.positive.voltageCandidateRaw == 406)
        #expect(payload.negative.voltageCandidateRaw == 402)
        #expect(payload.currentRaw == 3)
        #expect(payload.currentCandidateAmperes == 3)
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
