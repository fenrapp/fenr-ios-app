import Foundation

public struct StarkBatteryTemperaturesDecoder: StarkPayloadDecoding {
    public init() {}

    public func decode(_ data: Data) throws -> StarkBatteryTemperaturesPayload {
        guard data.count == StarkBatteryPayloadLayout.temperaturesLength else {
            throw StarkProtocolError.invalidPayloadLength(
                expected: StarkBatteryPayloadLayout.temperaturesLength,
                actual: data.count
            )
        }
        let reader = StarkByteReader(data: data)
        let celsius = (0 ..< StarkBatteryPayloadLayout.temperatureCount).map { index in
            let offset = index * StarkBatteryPayloadLayout.temperatureByteWidth
            return Double(reader.u16(at: offset)) / StarkBatteryPayloadLayout.temperatureScale
        }
        return StarkBatteryTemperaturesPayload(
            celsius: celsius,
            validSensorMask: Int(reader.u16(at: StarkBatteryPayloadLayout.temperaturesValidMaskOffset)),
            usedSensorCount: Int(reader.u8(at: StarkBatteryPayloadLayout.temperaturesUsedOffset))
        )
    }
}
