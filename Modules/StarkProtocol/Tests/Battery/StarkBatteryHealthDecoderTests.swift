import Foundation
import StarkProtocol
import Testing

@Suite("Stark battery health decoders")
struct StarkBatteryHealthDecoderTests {
    @Test("BMS status decodes positive and negative fault masks and accepts reserved trailing bytes")
    func bmsStatusDecodes() throws {
        let payload = try StarkBatteryStatusDecoder().decode(Data([
            0x78, 0x56, 0x34, 0x12,
            0xEF, 0xCD, 0xAB, 0x90,
            0, 0, 0, 0, 0, 0, 0, 0
        ]))

        #expect(payload.positiveFaultBits == 0x1234_5678)
        #expect(payload.negativeFaultBits == 0x90AB_CDEF)
        #expect(payload.isFaultActive)
    }

    @Test("BMS status rejects a payload shorter than its two confirmed masks")
    func incompleteBMSStatusIsRejected() {
        #expect(throws: StarkProtocolError.payloadTooShort(
            expected: StarkBatteryStatusPayloadLayout.requiredLength,
            actual: StarkBatteryStatusPayloadLayout.requiredLength - 1
        )) {
            try StarkBatteryStatusDecoder().decode(
                Data(repeating: 0, count: StarkBatteryStatusPayloadLayout.requiredLength - 1)
            )
        }
    }

    @Test("Cell voltages decode the observed 100-cell layout")
    func cellVoltagesDecode() throws {
        let payload = try StarkCellVoltagesDecoder().decode(StarkProtocolFixtures.observedCellVoltages)

        #expect(payload.volts.count == StarkBatteryPayloadLayout.cellVoltageCount)
        #expect(payload.volts.first == 3.8366)
        #expect(payload.volts[50] == 3.8286)
        #expect(payload.volts.max() == 3.8476)
    }

    @Test("Temperatures decode sensor values and metadata")
    func temperaturesDecode() throws {
        let payload = try StarkBatteryTemperaturesDecoder().decode(StarkProtocolFixtures.observedBatteryTemperatures)

        #expect(payload.celsius == [28.1, 28.4, 27.7, 27.7, 28.6, 28.0, 28.1, 28.5, 27.7, 27.7, 28.4, 27.8])
        #expect(payload.validSensorMask == 0)
        #expect(payload.usedSensorCount == 0)
    }

    @Test("Balancing decodes one bit per cell")
    func balancingDecode() throws {
        var bytes = StarkProtocolFixtures.observedBatteryBalancing
        bytes[0] = 0b0000_0001
        bytes[12] = 0b0000_1000

        let payload = try StarkBatteryBalancingDecoder().decode(bytes)

        #expect(payload.activeCellIndexes == Set([0, 99]))
    }

    @Test("Charger decodes observed limits and live current")
    func chargerDecodes() throws {
        let payload = try StarkChargerDecoder().decode(StarkProtocolFixtures.observedCharger)

        #expect(payload.requestedCurrentAmperes == 2.5)
        #expect(payload.reportedCurrentAmperes == 2.5)
        #expect(payload.targetCellVoltageVolts == 4.275)
        #expect(payload.maximumCurrentAmperes == 20)
        #expect(payload.maximumPowerWatts == 1_000)
        #expect(payload.maximumStateOfChargePercent == 100)
        #expect(payload.typeRaw == 3)
    }

    @Test("Advanced battery decoders reject incomplete captures")
    func incompleteCaptureIsRejected() {
        #expect(throws: StarkProtocolError.invalidPayloadLength(
            expected: StarkBatteryPayloadLayout.cellVoltagesLength,
            actual: StarkProtocolFixtures.observedCellVoltages.count - 1
        )) {
            try StarkCellVoltagesDecoder().decode(StarkProtocolFixtures.observedCellVoltages.dropLast())
        }
    }

    @Test("Charger decoder rejects an incomplete payload")
    func incompleteChargerCaptureIsRejected() {
        #expect(throws: StarkProtocolError.invalidPayloadLength(
            expected: StarkChargerPayloadLayout.length,
            actual: StarkChargerPayloadLayout.length - 1
        )) {
            try StarkChargerDecoder().decode(StarkProtocolFixtures.observedCharger.dropLast())
        }
    }
}
