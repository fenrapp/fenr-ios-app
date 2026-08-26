import Foundation

public struct StarkBatterySignalsDecoder: StarkPayloadDecoding {
    public init() {}

    public func decode(_ data: Data) throws -> StarkBatterySignalsPayload {
        let reader = StarkByteReader(data: data)
        try reader.require(StarkBatterySignalsPayloadLayout.requiredLength)

        return StarkBatterySignalsPayload(
            positive: decodeBMS(reader: reader, offset: StarkBatterySignalsPayloadLayout.positiveBMSOffset),
            negative: decodeBMS(reader: reader, offset: StarkBatterySignalsPayloadLayout.negativeBMSOffset),
            currentRaw: Int(reader.i16(at: StarkBatterySignalsPayloadLayout.currentOffset))
        )
    }

    private func decodeBMS(reader: StarkByteReader, offset: Int) -> StarkBMSSignalsPayload {
        StarkBMSSignalsPayload(
            dcBusRaw: Int(reader.u16(at: offset + StarkBatterySignalsPayloadLayout.dcBusOffset)),
            temperatureRaw: Int(reader.u16(at: offset + StarkBatterySignalsPayloadLayout.temperatureOffset)),
            humidityRaw: Int(reader.u16(at: offset + StarkBatterySignalsPayloadLayout.humidityOffset)),
            controlFlags: Int(reader.u16(at: offset + StarkBatterySignalsPayloadLayout.controlFlagsOffset))
        )
    }
}
