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

        let rawValues = (0 ..< StarkInverterTemperaturesPayloadLayout.temperatureCount).map { index in
            reader.u16(at: index * StarkInverterTemperaturesPayloadLayout.temperatureByteWidth)
        }
        return StarkInverterTemperaturesPayload(rawValues: rawValues)
    }
}
