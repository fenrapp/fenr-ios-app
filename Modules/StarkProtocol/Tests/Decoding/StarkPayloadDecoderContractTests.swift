import Foundation
import StarkProtocol
import Testing

@Suite("Stark payload decoder contract")
struct StarkPayloadDecoderContractTests {
    @Test("Every diagnostics decoder is usable through the common contract")
    func diagnosticsDecodersConform() throws {
        let battery = try decode(StarkBatteryDecoder(), data: StarkProtocolFixtures.batteryMinimum)
        let status = try decode(StarkStatusDecoder(), data: StarkProtocolFixtures.statusCrawlReverse)
        let map = try decode(StarkMapDecoder(), data: StarkProtocolFixtures.map)
        let speed = try decode(StarkSpeedDecoder(), data: StarkProtocolFixtures.speedZero)
        let vin = try decode(StarkVINDecoder(), data: StarkProtocolFixtures.vinPadded)
        let cells = try decode(StarkCellVoltagesDecoder(), data: StarkProtocolFixtures.observedCellVoltages)
        let temperatures = try decode(
            StarkBatteryTemperaturesDecoder(),
            data: StarkProtocolFixtures.observedBatteryTemperatures
        )
        let balancing = try decode(
            StarkBatteryBalancingDecoder(),
            data: StarkProtocolFixtures.observedBatteryBalancing
        )
        let inverterTemperatures = try decode(
            StarkInverterTemperaturesDecoder(),
            data: StarkProtocolFixtures.inverterTemperaturesWithStatus
        )
        let estimations = try decode(
            StarkLiveEstimationsDecoder(),
            data: StarkProtocolFixtures.liveEstimationsNegativePower
        )
        let batteryParameters = try decode(
            StarkBatteryParametersDecoder(),
            data: StarkProtocolFixtures.batteryParameters
        )
        let batterySignals = try decode(
            StarkBatterySignalsDecoder(),
            data: StarkProtocolFixtures.batterySignalsNegativeCurrent
        )

        #expect(battery.stateOfChargePercent == 91)
        #expect(status.isCrawlActive)
        #expect(map.modeIndex == 3)
        #expect(speed.motorRPM == 0)
        #expect(vin.value == StarkProtocolFixtures.referenceVIN)
        #expect(cells.volts.count == StarkBatteryPayloadLayout.cellVoltageCount)
        #expect(temperatures.celsius.count == StarkBatteryPayloadLayout.temperatureCount)
        #expect(balancing.activeCellIndexes.isEmpty)
        #expect(inverterTemperatures.rawValues.count == StarkInverterTemperaturesPayloadLayout.temperatureCount)
        #expect(estimations.nativeMotorPowerRaw == -100)
        #expect(batteryParameters.capacityRaw == 0x1234)
        #expect(batterySignals.currentRaw == -8)
    }

    @Test("Payload constants match decoder contracts")
    func payloadConstants() {
        #expect(StarkBatteryPayloadLayout.minimumLength == 2)
        #expect(StarkBatteryStatusPayloadLayout.requiredLength == 8)
        #expect(StarkSpeedPayloadLayout.requiredLength == 4)
        #expect(StarkStatusPayloadLayout.requiredLength == 18)
        #expect(StarkStatusPayloadLayout.batteryStatusOffset == 14)
        #expect(StarkBatteryPayloadLayout.cellVoltagesLength == 200)
        #expect(StarkBatteryPayloadLayout.temperaturesLength == 27)
        #expect(StarkBatteryPayloadLayout.balancingLength == 13)
        #expect(StarkInverterTemperaturesPayloadLayout.requiredLength == 16)
        #expect(StarkLiveEstimationsPayloadLayout.requiredLength == 6)
        #expect(StarkBatteryParametersPayloadLayout.requiredLength == 4)
        #expect(StarkBatterySignalsPayloadLayout.requiredLength == 18)
    }

    private func decode<Decoder: StarkPayloadDecoding>(
        _ decoder: Decoder,
        data: Data
    ) throws -> Decoder.Payload {
        try decoder.decode(data)
    }
}
