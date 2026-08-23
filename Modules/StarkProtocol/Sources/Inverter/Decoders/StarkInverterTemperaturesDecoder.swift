import Foundation

public struct StarkInverterTemperaturesDecoder: StarkPayloadDecoding {
    public init() {}

    public func decode(_ data: Data) throws -> StarkInverterTemperaturesPayload {
        let reader = StarkByteReader(data: data)
        try reader.require(StarkInverterTemperaturesPayloadLayout.requiredLength)

        let rawValues = (0 ..< StarkInverterTemperaturesPayloadLayout.temperatureCount).map { index in
            reader.u16(at: index * StarkInverterTemperaturesPayloadLayout.temperatureByteWidth)
        }
        return StarkInverterTemperaturesPayload(rawValues: rawValues)
    }
}
