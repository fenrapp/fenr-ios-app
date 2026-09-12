import Foundation

public struct StarkInverterTemperaturesDecoder: StarkPayloadDecoding {
    public init() {}

    public func decode(_ data: Data) throws -> StarkInverterTemperaturesPayload {
        guard data.count == StarkInverterTemperaturesPayloadLayout.requiredLength else {
            throw StarkProtocolError.invalidPayloadLength(
                expected: StarkInverterTemperaturesPayloadLayout.requiredLength,
                actual: data.count
            )
        }
        let reader = StarkByteReader(data: data)

        return StarkInverterTemperaturesPayload(
            motor: decodeGroup(reader, at: .zero),
            igbt: decodeGroup(reader, at: StarkInverterTemperaturesPayloadLayout.groupByteWidth)
        )
    }

    private func decodeGroup(
        _ reader: StarkByteReader,
        at offset: Int
    ) -> StarkInverterTemperaturesPayload.SensorGroup {
        let rawValues = (0 ..< StarkInverterTemperaturesPayloadLayout.temperaturesPerGroup).map { index in
            reader.u16(at: offset + index * StarkInverterTemperaturesPayloadLayout.temperatureByteWidth)
        }
        // The trailing bytes describe sensor status, not another temperature.
        return .init(
            rawValues: rawValues,
            validStatus: reader.u8(at: offset + StarkInverterTemperaturesPayloadLayout.validStatusOffset),
            usedStatus: reader.u8(at: offset + StarkInverterTemperaturesPayloadLayout.usedStatusOffset)
        )
    }
}
